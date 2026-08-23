# DeepSeek Harness (dsh) 离线部署包

本仓库自动跟踪 `@deepseek-ai/dsh` npm 包最新版，定时生成 **Windows x64 离线部署包**并发布到 GitHub Releases。

- 用法：在本仓库 **Releases** 页面下载最新 `deepseek-harness-offline-win-x64.zip`
- 要求目标机 Node.js `^22.19.0` 或 `>=24.0.0`，无需 pnpm、无需联网
- 详见离线包内 `安装说明.md`

仓库由 GitHub Actions 定时自动维护（`.github/workflows/offline-build.yml`）。