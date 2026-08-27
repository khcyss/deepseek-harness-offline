@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

rem ============================================================
rem  dsh offline pack - npm-style setup
rem  Installs dsh into the SAME location as `npm install -g`:
rem    <npm-prefix>\node_modules\@deepseek-ai\dsh\...   program files
rem    <npm-prefix>\dsh.cmd                            global bin (PATH)
rem  <npm-prefix> defaults to the npm global prefix (npm prefix -g,
rem  e.g. %APPDATA%\npm). You can override it with an argument.
rem
rem  Usage:
rem    setup.cmd            install into npm global prefix
rem    setup.cmd <prefix>   install into <prefix> (npm-style layout)
rem ============================================================

set "HERE=%~dp0"
set "BUNDLE=%HERE%bundle"
if not exist "%BUNDLE%\node_modules\@deepseek-ai\dsh\lib\bin.js" (
  echo [ERROR] bundle not found next to setup.cmd: "%BUNDLE%"
  exit /b 1
)

set "PREFIX="
if not "%~1"=="" set "PREFIX=%~1"
if "%PREFIX%"=="" (
  for /f "delims=" %%P in ('npm prefix -g 2^>nul') do set "PREFIX=%%P"
)
if "%PREFIX%"=="" (
  echo [ERROR] cannot resolve npm global prefix ^(npm prefix -g^); pass one explicitly:
  echo         setup.cmd D:\some\prefix
  exit /b 1
)
echo Using npm-style prefix: "%PREFIX%"

echo [1/3] Copying dsh package + deps into "%PREFIX%\node_modules\@deepseek-ai\dsh" ...
if not exist "%PREFIX%\node_modules" mkdir "%PREFIX%\node_modules"
xcopy /E /I /Y "%BUNDLE%\node_modules\@deepseek-ai\dsh" "%PREFIX%\node_modules\@deepseek-ai\dsh" >nul
if errorlevel 1 ( echo [ERROR] copy dsh package failed. & exit /b 1 )

echo [2/3] Copying the rest of the dependency tree into "%PREFIX%\node_modules" ...
xcopy /E /I /H /Y "%BUNDLE%\node_modules\*" "%PREFIX%\node_modules\" >nul

echo [3/3] Writing global bin shim "%PREFIX%\dsh.cmd" ...
> "%PREFIX%\dsh.cmd" echo @echo off
>> "%PREFIX%\dsh.cmd" echo chcp 65001 ^>nul
>> "%PREFIX%\dsh.cmd" echo setlocal
>> "%PREFIX%\dsh.cmd" echo node "%%~dp0node_modules\@deepseek-ai\dsh\lib\bin.js" %%*
>> "%PREFIX%\dsh.cmd" echo exit /b %%errorlevel%%

echo.
echo [OK] dsh installed npm-style.
echo   Open a NEW terminal, then run:  dsh web
echo   Program files: %PREFIX%\node_modules\@deepseek-ai\dsh
echo   Bin: %PREFIX%\dsh.cmd  ^(this dir is on PATH like any npm global bin^)
echo   Data dir ^(DSH_HOME^) defaults to %%USERPROFILE%%\.dsh; set it freely, e.g. setx DSH_HOME D:\dsh-data
echo.
echo   Uninstall: delete %PREFIX%\node_modules\@deepseek-ai\dsh and %PREFIX%\dsh.cmd
endlocal
exit /b 0