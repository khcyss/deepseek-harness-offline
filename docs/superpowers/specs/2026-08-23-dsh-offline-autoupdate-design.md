# dsh 离线包自动更新管线 设计

日期：2026-08-23
状态：待评审

## 目标

让 `khcyss/deepseek-harness-offline` 仓库自动跟踪 DeepSeek Harness（`@deepseek-ai/dsh`）npm 包的最新版，定期重打 **win-x64 离线部署包**（与当前手工制作流程一致），并发布到 GitHub Release，供无外网局域网机器下载使用。

## 背景与已定决策

| 决策点 | 结论 | 说明 |
| --- | --- | --- |
| 运行位置 | **GitHub Actions（windows-latest）定时** | 不依赖开发机是否开机；云端构建；推送用仓库内置 `GITHUB_TOKEN` |
| 存放方式 | **发布到 GitHub Release** | 仓库保持轻量；Release 有版本号和下载按钮 |
| 版本来源 | **npm `dist-tags.latest`** | 当前为 `0.1.1-rc.2` |
| 构建参数 | `npm install @deepseek-ai/dsh@<ver> --omit=dev` + `NODE_OPTIONS=--max-old-space-size=6144` | 本机实测默认 2GB 堆会 OOM，8GB 可过；runner 内存约 7GB，用 6GB 保险 |
| 打包方式 | PowerShell `Compress-Archive` | Windows 原生，能正确保留 `安装说明.md` 中文文件名 |

## 工作流：`.github/workflows/offline-build.yml`

触发：
- `schedule`：cron 每日一次（如 `17 3 * * *` UTC），避开整点
- `workflow_dispatch`：手动兜底

步骤：
1. `actions/checkout`（注意用 `persist-credentials: false`，之后统一用 gh）
2. 取最新版：`npm view @deepseek-ai/dsh dist-tags.latest --json`；读仓库 `latest-version.txt`
3. 相等 → 结束（输出 `SKIP: no update`）；不等 → 继续
4. `actions/setup-node`（node `'22'`，满足 `^22.19.0 || >=24.0.0`）
5. 构建：`npm init -y` + `NODE_OPTIONS=--max-old-space-size=6144 npm install @deepseek-ai/dsh@<ver> --omit=dev --no-audit --no-fund`
6. 装配：把 `templates/` 下 `dsh.cmd`、`check-node.cmd`、`安装说明.md` 复制进 `bundle/`，替换 `{DSH_VERSION}`、`{BUILD_DATE}` 占位符
7. 打包：`Compress-Archive -Path bundle -DestinationPath deepseek-harness-offline-win-x64.zip -CompressionLevel Optimal`
8. 自检：解压 zip → 断言 `node_modules/@deepseek-ai/dsh/lib/bin.js` 存在、zip > 50MB、`node -e` 读到版本与 `latest-version.txt` 一致
9. 提交：更新 `latest-version.txt=<ver>`，配置 git 身份（用 `github.actor` 或固定 bot 名），`git commit` + `push`（工作流 `permissions: contents: write`）
10. 发布：`gh release create dsh-<ver> --title "<ver>" --generate-notes`（若无），再 `gh release upload dsh-<ver> <zip> --clobber`；若同名 tag 的 Release 已存在则先重建

失败处理：任一步失败 → job 红；**不**更新 `latest-version.txt`（下次触发重试）；已有 Release 不受影响。

## 仓库结构

```
deepseek-harness-offline/
├── .github/workflows/offline-build.yml   # 上述工作流
├── templates/
│   ├── dsh.cmd            # 离线启动脚本（含 DSH_HOME、node 直跑 bin.js）
│   ├── check-node.cmd     # Node 版本校验（^22.19.0 || >=24.0.0）
│   └── 安装说明.md          # 目标机全流程 + 排错（占位符 {DSH_VERSION}/{BUILD_DATE}）
├── latest-version.txt     # 已打包版本记录（工作流维护）
├── README.md              # 下载/使用说明
└── docs/superpowers/specs/…-design.md  # 本文档
```

模板均沿用此前在开发机验证过的脚本内容（`dsh.cmd` 用 `node "%~dp0node_modules\@deepseek-ai\dsh\lib\bin.js" web %*`，`check-node.cmd` 校验 Node 版本），只把版本改为占位符。

## 初始搭建与认证

- 一次性：把上述初始内容 push 进空仓库；之后全自动。
- 认证：优先测本机已有 TortoiseGit 配置；不行则生成 SSH 密钥，用户把公钥加到 GitHub，改走 SSH 远程 URL。

## 验证

- 首次用 `workflow_dispatch` 手动触发，检查 job 各步骤通过、Release 出现、zip 可下载。
- 下载 Release zip 到本地解压，跑 `check-node.cmd` 与 `dsh web --no-open`，确认可启动（等价于在局域网机器验证）。
- 二次触发同一版本：预期 `SKIP`，不产生新 Release。

## 不在范围

- Docker/K8s 离线镜像包
- 桌面版安装包
- 多架构（仅 win-x64，因离线机为 Windows）