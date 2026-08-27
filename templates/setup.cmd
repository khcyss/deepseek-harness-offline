@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

rem ============================================================
rem  dsh offline pack - npm-style setup
rem  Installs the bundle to a fixed prefix (default D:\dsh),
rem  registers a `dsh` command on the user PATH (like npm's
rem  global bin), and points DSH_HOME under the prefix.
rem
rem  Usage:
rem    setup.cmd                prefix = D:\dsh
rem    setup.cmd <path>         prefix = <path>
rem    SET DSH_PREFIX=<path> & setup.cmd
rem ============================================================

set "HERE=%~dp0"
set "PREFIX=D:\dsh"
if defined DSH_PREFIX set "PREFIX=%DSH_PREFIX%"
if not "%~1"=="" set "PREFIX=%~1"

set "BUNDLE=%HERE%bundle"
if not exist "%BUNDLE%\node_modules\@deepseek-ai\dsh\lib\bin.js" (
  echo [ERROR] bundle not found next to setup.cmd: "%BUNDLE%"
  exit /b 1
)

echo [1/3] Installing program files to "%PREFIX%\bundle" ...
if not exist "%PREFIX%" mkdir "%PREFIX%"
if exist "%PREFIX%\bundle" rmdir /S /Q "%PREFIX%\bundle"
xcopy /E /I /Y "%BUNDLE%" "%PREFIX%\bundle" >nul
if errorlevel 1 ( echo [ERROR] copy bundle failed. & exit /b 1 )

echo [2/3] Writing command shim "%PREFIX%\dsh.cmd" ...
> "%PREFIX%\dsh.cmd" echo @echo off
>> "%PREFIX%\dsh.cmd" echo chcp 65001 ^>nul
>> "%PREFIX%\dsh.cmd" echo setlocal
>> "%PREFIX%\dsh.cmd" echo node "%%~dp0bundle\node_modules\@deepseek-ai\dsh\lib\bin.js" %%*
>> "%PREFIX%\dsh.cmd" echo exit /b %%errorlevel%%

echo [3/3] Setting user env: DSH_HOME and PATH ...
if defined DSH_NOENV (
  echo   [test mode] DSH_NOENV is set - skipping env writes.
) else (
  setx DSH_HOME "%PREFIX%\.dsh" >nul
  powershell -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('Path','User');$pre='%PREFIX%';if(-not ($p -like '*'+$pre+'*')){[Environment]::SetEnvironmentVariable('Path',$pre+';'+$p,'User')}"
)

echo.
echo [OK] dsh installed to "%PREFIX%".
echo   Open a NEW terminal, then run:  dsh web
echo   Data dir: DSH_HOME=%PREFIX%\.dsh
echo   To uninstall: delete "%PREFIX%", then remove DSH_HOME and the "%PREFIX%" PATH entry.
endlocal
exit /b 0