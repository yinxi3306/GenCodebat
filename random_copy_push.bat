@echo off
setlocal
cd /d "%~dp0"

if "%~1"=="" (
  echo Usage: %~nx0 ^<path-to-source-project^>
  echo Example: %~nx0 D:\workspace\OtherRepo
  echo.
  echo Tip: Drag the source folder onto this bat, or run from cmd with the path as first argument.
  pause
  exit /b 1
)

if not exist "%~1\" (
  echo Error: source path does not exist or is not a directory:
  echo   %~1
  echo.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_copy_push.ps1" -SourceRoot "%~1"
set "ERR=%ERRORLEVEL%"

echo.
if %ERR% neq 0 (
  echo Script exited with code %ERR%.
)
pause
exit /b %ERR%
