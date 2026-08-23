@echo off
chcp 65001 >nul
setlocal
rem DeepSeek Harness (dsh) offline launcher.
rem Runs the bundled @deepseek-ai/dsh web UI directly via Node, no npx/network needed.

if not defined DSH_HOME set "DSH_HOME=%USERPROFILE%\.dsh"

node "%~dp0node_modules\@deepseek-ai\dsh\lib\bin.js" web %*

exit /b %errorlevel%
