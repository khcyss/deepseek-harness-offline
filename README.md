# DeepSeek Harness (dsh) 离线部署包

本仓库自动跟踪 `@deepseek-ai/dsh` npm 包最新版，定时生成 **Windows x64 离线部署包**并发布到 GitHub Releases。

- 用法：在本仓库 **Releases** 页面下载最新 `deepseek-harness-offline-win-x64.zip`
- 要求目标机 Node.js `^22.19.0` 或 `>=24.0.0`，无需 pnpm、无需联网
- 详见离线包内 `安装说明.md`

仓库由 GitHub Actions 定时自动维护（`.github/workflows/offline-build.yml`）。

## 可下载的离线配套工具（`downloads/`）

| 文件 | 说明 |
| --- | --- |
| `dsh-routing-suite-offline-win-x64.zip` | dsh-routing-suite 离线套装（injector v0.3.3 + Router Standard/Spec/React 预设），一条命令装配、全程离线；安装步骤见包内 `安装说明.md` |
| `pnpm-offline-win-x64.zip` | 离线 pnpm 11.23.0（免安装）：解压后 `setx PATH "%PATH%;D:\pnpm-offline"` 重开终端即可用 |
| `dsh-agent-teams-offline-win-x64.zip` | dsh-agent-teams v0.1.13 离线插件（多 Agent 团队协作，Web 卡片式监控，零运行时依赖）：`D:\dsh-agent-teams-offline\install.cmd` 一键离线装配；安装步骤见包内 `安装说明.md` |

> dsh 本体离线包（随 npm 新版本自动构建）请到 **[Releases](https://github.com/khcyss/deepseek-harness-offline/releases)** 页下载 `deepseek-harness-offline-win-x64.zip`，无需在本仓库内提交二进制。