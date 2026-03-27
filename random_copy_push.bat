@echo off

setlocal

cd /d "%~dp0"



set "SKIP_PAUSE="

if /i "%~2"=="NOPAUSE" set "SKIP_PAUSE=1"

if /i "%~1"=="NOPAUSE" set "SKIP_PAUSE=1"

if /i "%~1"=="NOPAUSE" (

  if not exist "%~dp0gencodebat.config.json" (

    echo Error: gencodebat.config.json not found next to this script.

    if not defined SKIP_PAUSE pause

    exit /b 1

  )

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_copy_push.ps1"

  set "ERR=%ERRORLEVEL%"

  goto :after_run

)



if "%~1"=="" (

  if not exist "%~dp0gencodebat.config.json" (

    echo Usage: %~nx0 ^<path-to-source-project^> [NOPAUSE]

    echo    Or: %~nx0 [NOPAUSE]  with SourceRoot set in gencodebat.config.json

    echo Example: %~nx0 D:\workspace\OtherRepo

    echo.

    echo Tip: Drag the source folder onto this bat, or run from cmd with the path as first argument.

    echo Second arg NOPAUSE skips all pauses ^(for scripted calls^).

    if not defined SKIP_PAUSE pause

    exit /b 1

  )

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_copy_push.ps1"

  set "ERR=%ERRORLEVEL%"

  goto :after_run

)



if not exist "%~1\" (

  echo Error: source path does not exist or is not a directory:

  echo   %~1

  echo.

  if not defined SKIP_PAUSE pause

  exit /b 1

)



powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_copy_push.ps1" -SourceRoot "%~1"

set "ERR=%ERRORLEVEL%"



:after_run

echo.

if %ERR% neq 0 (

  echo Script exited with code %ERR%.

)

if not defined SKIP_PAUSE pause

exit /b %ERR%

