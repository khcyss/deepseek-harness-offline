# dsh 离线包自动更新管线 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `khcyss/deepseek-harness-offline` 仓库实现 GitHub Actions 自动更新管线：检测 `@deepseek-ai/dsh` npm `latest` 版本，有更新就在 `windows-latest` 构建 win-x64 离线包并发布到 Release。

**Architecture:** 每日 `schedule` + `workflow_dispatch` 触发一个工作流，先比对 npm `dist-tags.latest` 与仓库 `latest-version.txt`，无更新即跳过；有更新则 `npm install --omit=dev` 构建 `bundle/`，套用 `templates/` 三个文件（替换版本/日期占位符），`Compress-Archive` 压成 zip，自检后提交版本号并 `gh release` 发布 zip。

**Tech Stack:** GitHub Actions（windows-latest）、PowerShell 5.1、npm、`gh` CLI（runner 预装）。

## Global Constraints

- Node 版本要求：`^22.19.0 || >=24.0.0`（工作流用 `actions/setup-node` node `'22'`）
- npm 安装必须 `NODE_OPTIONS=--max-old-space-size=6144`（默认 2GB 堆会 OOM，本机已实测）
- 打包走 PowerShell `Compress-Archive`（系统自带 tar 会丢弃中文文件名，禁用）
- 版本跟踪渠道：npm `dist-tags.latest`
- Release tag 命名：`dsh-<版本>`；资产文件固定名 `deepseek-harness-offline-win-x64.zip`
- zip 内顶层目录必须为 `bundle/`（与 `安装说明.md` 的解压指引一致）
- 目标仓库默认分支 `main`；推送用工作流 `GITHUB_TOKEN`（`permissions: contents: write`）
- 初始 `latest-version.txt` 为空 → 首次运行即构建当前最新版

---

### Task 1: 创建 GitHub Actions 工作流

**Files:**
- Create: `.github/workflows/offline-build.yml`

**Interfaces:**
- Consumes: `latest-version.txt`（Task 2 创建）
- Produces: 定时/手动可触发的工作流；成功后更新 `latest-version.txt` 并发布 Release

- [ ] **Step 1: 写工作流文件**

创建 `.github/workflows/offline-build.yml`，内容如下：

```yaml
name: Build and Publish dsh Offline Package

on:
  schedule:
    - cron: '17 3 * * *'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build:
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: '22'

      - name: Resolve latest dsh version
        id: version
        shell: pwsh
        run: |
          $latest = (npm view @deepseek-ai/dsh dist-tags.latest) -join ''
          $current = ((Get-Content latest-version.txt -Raw) -join '').Trim()
          $date = Get-Date -Format 'yyyy-MM-dd'
          "latest=$latest" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
          "current=$current" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
          "build_date=$date" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
          Write-Output "remote latest=$latest current=$current"

      - name: Decide whether to build
        id: check
        shell: bash
        run: |
          if [ "${{ steps.version.outputs.latest }}" = "${{ steps.version.outputs.current }}" ]; then
            echo "No update; skip build."
            echo "should_build=false" >> "$GITHUB_OUTPUT"
          else
            echo "New version detected."
            echo "should_build=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Build node_modules bundle
        if: steps.check.outputs.should_build == 'true'
        shell: pwsh
        run: |
          $ver = "${{ steps.version.outputs.latest }}"
          New-Item -ItemType Directory -Force -Path bundle | Out-Null
          Push-Location bundle
          Set-Content -Path package.json -Value '{ "name": "dsh-offline", "private": true }' -Encoding utf8
          $env:NODE_OPTIONS = "--max-old-space-size=6144"
          npm install "@deepseek-ai/dsh@$ver" --omit=dev --no-audit --no-fund
          if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
          Pop-Location
          Write-Output "bundle built for $ver"

      - name: Assemble launcher templates
        if: steps.check.outputs.should_build == 'true'
        shell: pwsh
        run: |
          $ver = "${{ steps.version.outputs.latest }}"
          $date = "${{ steps.version.outputs.build_date }}"
          Copy-Item templates/dsh.cmd bundle/dsh.cmd
          Copy-Item templates/check-node.cmd bundle/check-node.cmd
          (Get-Content 'templates/安装说明.md' -Raw).Replace('{DSH_VERSION}',$ver).Replace('{BUILD_DATE}',$date) | Set-Content 'bundle/安装说明.md' -Encoding utf8

      - name: Create zip
        if: steps.check.outputs.should_build == 'true'
        shell: pwsh
        run: |
          Compress-Archive -Path bundle -DestinationPath deepseek-harness-offline-win-x64.zip -CompressionLevel Optimal
          $mb = [math]::Round((Get-Item deepseek-harness-offline-win-x64.zip).Length / 1MB, 1)
          Write-Output "zip created: $mb MB"

      - name: Self-check zip
        if: steps.check.outputs.should_build == 'true'
        shell: pwsh
        run: |
          New-Item -ItemType Directory -Force -Path _check | Out-Null
          Expand-Archive -Path deepseek-harness-offline-win-x64.zip -DestinationPath _check -Force
          $bin = '_check/bundle/node_modules/@deepseek-ai/dsh/lib/bin.js'
          if (-not (Test-Path $bin)) { throw "self-check failed: $bin missing" }
          $pkg = Get-Content '_check/bundle/node_modules/@deepseek-ai/dsh/package.json' -Raw | ConvertFrom-Json
          if ($pkg.version -ne "${{ steps.version.outputs.latest }}") { throw "self-check failed: bundled version $($pkg.version)" }
          if ((Get-Item deepseek-harness-offline-win-x64.zip).Length -lt 50MB) { throw "self-check failed: zip too small" }
          Write-Output "self-check ok: bundled $($pkg.version)"

      - name: Commit version bump
        if: steps.check.outputs.should_build == 'true'
        shell: bash
        run: |
          echo "${{ steps.version.outputs.latest }}" > latest-version.txt
          git config user.name "khcyss[bot]"
          git config user.email "khcyss[bot]@users.noreply.github.com"
          git add latest-version.txt
          git commit -m "chore: bump offline package to ${{ steps.version.outputs.latest }}"
          git push origin HEAD:main

      - name: Publish GitHub Release
        if: steps.check.outputs.should_build == 'true'
        env:
          GH_TOKEN: ${{ github.token }}
        shell: bash
        run: |
          VER="${{ steps.version.outputs.latest }}"
          TAG="dsh-$VER"
          gh release delete "$TAG" --repo khcyss/deepseek-harness-offline --yes --cleanup-tag >/dev/null 2>&1 || true
          gh release create "$TAG" deepseek-harness-offline-win-x64.zip \
            --repo khcyss/deepseek-harness-offline \
            --title "dsh $VER 离线包" \
            --notes "DeepSeek Harness offline package for Windows x64 (dsh $VER, built ${{ steps.version.outputs.build_date }}). Download then extract to D:\deepseek-harness\bundle per the included install guide."
```

- [ ] **Step 2: 校验 YAML 基本语法（本地快速检查）**

Run: `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/offline-build.yml',encoding='utf-8')); print('yaml ok')"`（本机若无 pyyaml，则跳过此步，以 GitHub 实际运行为准）

- [ ] **Step 3: 提交**

```bash
git add .github/workflows/offline-build.yml
git commit -m "ci: add dsh offline package auto-build workflow"
```

### Task 2: 创建模板与版本文件

**Files:**
- Create: `templates/dsh.cmd`
- Create: `templates/check-node.cmd`
- Create: `templates/安装说明.md`
- Create: `latest-version.txt`（空文件）

**Interfaces:**
- Consumes: 无（纯资产）
- Produces: 工作流构建时复制进 `bundle/` 的三个文件；`latest-version.txt` 供 Task 1 比对

- [ ] **Step 1: 写 `templates/dsh.cmd`**

```bat
@echo off
chcp 65001 >nul
setlocal
rem DeepSeek Harness (dsh) offline launcher.
rem Runs the bundled @deepseek-ai/dsh web UI directly via Node, no npx/network needed.

if not defined DSH_HOME set "DSH_HOME=%USERPROFILE%\.dsh"

node "%~dp0node_modules\@deepseek-ai\dsh\lib\bin.js" web %*

exit /b %errorlevel%
```

- [ ] **Step 2: 写 `templates/check-node.cmd`**

```bat
@echo off
chcp 65001 >nul
setlocal

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js was not found in PATH. dsh requires Node.js ^22.19.0 or >=24.0.0.
  exit /b 1
)

for /f "delims=" %%v in ('node -v') do set NODE_VER=%%v
echo Detected Node.js: %NODE_VER%

node -e "const s=process.versions.node.split('.').map(Number);const[a,b]=s;const ok=(a>22||(a===22&&b>=19))||(a>=24);if(!ok){console.error('[ERROR] dsh requires Node.js ^22.19.0 or >=24.0.0; got '+process.version+'. Please upgrade Node.js.');process.exit(1)}else{console.log('[OK] Node version satisfies the dsh requirement.')}"

exit /b %errorlevel%
```

- [ ] **Step 3: 写 `templates/安装说明.md`**

```markdown
# DeepSeek Harness (dsh) 离线部署包安装说明

本包是 DeepSeek Harness（官方开源 Agent 运行时，简称 dsh）的 **Windows x64 离线部署包**：
依赖已在构建机上预装为完整 `node_modules`，目标机**无需联网、无需 pnpm、无需编译**，只要有 Node.js 即可直接运行。

- 内置版本：`@deepseek-ai/dsh@{DSH_VERSION}`
- 构建日期：`{BUILD_DATE}`
- 要求 Node.js：`^22.19.0` 或 `>=24.0.0`
- 默认访问地址：`http://127.0.0.1:3080`（仅本机监听）

## 包内结构

```
bundle/
├── node_modules/          <-- 已预装的全部依赖（Windows x64，勿移植其他平台）
├── package.json
├── dsh.cmd                <-- 启动脚本
├── check-node.cmd         <-- 环境检查脚本
└── 安装说明.md            <-- 本文件
```

## 第一步：解压到目标机

把 `deepseek-harness-offline-win-x64.zip` 拷贝到离线 Windows 电脑，解压到 `D:\`（推荐 `D:\deepseek-harness`），使 `bundle\dsh.cmd` 存在。

## 第二步：（推荐）让 dsh 数据也放 D 盘

```bat
setx DSH_HOME "D:\deepseek-harness\.dsh"
```

> 打开新终端后生效；也可不设置，用默认位置 `C:\Users\<用户名>\.dsh`。

## 第三步：检查 Node 环境

```bat
D:\deepseek-harness\bundle\check-node.cmd
```

看到 `[OK] Node version satisfies the dsh requirement.` 即可。

## 第四步：启动

```bat
D:\deepseek-harness\bundle\dsh.cmd web
```

启动成功打印 `dsh web: http://127.0.0.1:3080`，自动开浏览器；也可手动访问。

> 可选：`dsh.cmd web --no-open`、`dsh.cmd web --port 8080`。

## 第五步：首次使用（安全第一）

1. 打开 Web UI 后，左上角【选择工作区】，**必须选一个全新的空文件夹**（Agent 拥有本机 Shell 高权限）。
2. 配置模型：Settings / 设置 → Models / 模型，添加 **OpenAI 兼容** Provider，Base URL 填局域网模型服务地址（例 Ollama `http://<服务机IP>:11434/v1`），填本地模型 ID，API Key 任意。
3. 验证：新开会话发一条任务，确认有模型回复。

## 常见问题排查

| 现象 | 处理 |
| --- | --- |
| `check-node.cmd` 提示版本不足 | 升级系统 Node.js 到 `^22.19.0` 或 `>=24.0.0` |
| 提示 `Node.js was not found in PATH` | 安装 Node.js 并加入 PATH，重开终端 |
| 端口 3080 被占用 | `dsh.cmd web --port 8080` |
| 页面空白 / 插件树异常 | `dsh.cmd web --dump-config` 查加载 |
| 启动后刷 `ECONNREFUSED` / 卡重试 | dev-preview 已知风险；把启动日志发给维护者 |
| Windows 下 Shell 命令受限 | 查看 dsh 官方 Windows 沙箱文档放宽策略 |

## 风险提示

- dsh 处于 developer preview，版本迭代快、可能有破坏性变更；本包版本字段见上文，以 Release 为准。
- 包内**不含模型权重**，运行时只连你配置的局域网模型服务；启动本身**无需外网**。
- 本 `node_modules` 按 **Windows x64** 预装，请勿移植到其他平台/架构。
```

- [ ] **Step 4: 创建 `latest-version.txt`（空）**

```bash
: > latest-version.txt
```

- [ ] **Step 5: 提交**

```bash
git add templates/ latest-version.txt
git commit -m "feat: add offline bundle templates and version tracker"
```

### Task 3: 推送并手动触发验证

**Files:**
- No new files

**Interfaces:**
- Consumes: Task 1、Task 2 已提交的全部文件
- Produces: 仓库线上可用；手动触发后产出 Release 资产

- [ ] **Step 1: 推送到 GitHub**

```bash
git push origin main
```

Run: `git ls-remote origin` 应看到 `main` 有最新提交。

- [ ] **Step 2: 手动触发工作流（需用户在 GitHub 操作）**

浏览器打开 `https://github.com/khcyss/deepseek-harness-offline/actions/workflows/offline-build.yml` → **Run workflow**（branch：main）→ Run。

- [ ] **Step 3: 观察运行结果**

预期：job 依次通过 Checkout → Node → Resolve（输出 `remote latest=0.1.x current=`）→ Decide（`New version detected`）→ Build → Assemble → zip → Self-check（`zip ok`）→ Commit → Publish。结束后仓库出现：

- `latest-version.txt` 内容变为 `0.1.1-rc.2`（或当时 latest）
- Release `dsh-<版本>` 带 `deepseek-harness-offline-win-x64.zip` 资产

若某一版本已经存在（current=latest）则只会 `No update; skip build.`，无 Release 变更。

- [ ] **Step 4: 下载产物本地验证（可选但在局域网机器等效）**

从 Release 下载 zip，解压后运行 `check-node.cmd` 应 `[OK]`；运行 `dsh web --no-open` 后 `curl http://127.0.0.1:3080` 应返回 200。

---

## 无占位符自审

- Task 1 提供了完整 workflow YAML，含全部 shell/pwsh 代码块。
- Task 2 提供了三个模板文件全文。
- Task 3 给出验证动作与预期判据。
- 类型/路径一致性：`latest-version.txt` 在 Task2 创建、Task1 读取、Task3 验证；`bundle/` 根目录结构一致；tag `dsh-<ver>` 在 workflow 与验证中一致。