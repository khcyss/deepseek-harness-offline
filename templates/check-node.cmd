@echo off
chcp 65001 >nul
setlocal

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js was not found in PATH. dsh requires Node.js ^^22.19.0 or ^>=24.0.0.
  exit /b 1
)

for /f "delims=" %%v in ('node -v') do set NODE_VER=%%v
echo Detected Node.js: %NODE_VER%

node -e "const s=process.versions.node.split('.').map(Number);const[a,b]=s;const ok=((a===22&&b>=19)||a>=24);if(!ok){console.error('[ERROR] dsh requires Node.js ^22.19.0 or >=24.0.0; got '+process.version+'. Please upgrade Node.js.');process.exit(1)}else{console.log('[OK] Node version satisfies the dsh requirement.')}"

exit /b %errorlevel%
