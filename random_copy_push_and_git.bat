@echo off

setlocal EnableDelayedExpansion

cd /d "%~dp0"

set "ITERATIONS=10"
for /f "usebackq delims=" %%n in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_copy_push.ps1" -EmitIterations`) do set "ITERATIONS=%%n"

if "%~1"=="" (

  if not exist "%~dp0gencodebat.config.json" (

    echo Usage: %~nx0 ^<path-to-source-project^>

    echo    Or: %~nx0  with SourceRoot in gencodebat.config.json

    echo   Repeats %ITERATIONS% times: append snippets, then commit and push when there are changes.

    echo Example: %~nx0 D:\workspace\OtherRepo

    pause

    exit /b 1

  )

  set "RCP_FROM_CONFIG=1"

  set "RCP_SOURCE="

) else (

  if not exist "%~1\" (

    echo Error: source path does not exist or is not a directory:

    echo   %~1

    pause

    exit /b 1

  )

  set "RCP_FROM_CONFIG="

  set "RCP_SOURCE=%~1"

)



git rev-parse --is-inside-work-tree >nul 2>&1

if errorlevel 1 (

  echo Error: not a git repository.

  pause

  exit /b 1

)



set "SNIP1="

set "SNIP2="

for /f "usebackq tokens=1,* delims=|" %%a in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_copy_push.ps1" -EmitOutputPaths`) do (

  set "SNIP1=%%a"

  set "SNIP2=%%b"

)



if not defined SNIP1 (

  echo Error: could not resolve snippet paths from configuration.

  pause

  exit /b 1

)



for /l %%i in (1,1,%ITERATIONS%) do (

  echo.

  echo ===== Round %%i / %ITERATIONS% =====

  if defined RCP_FROM_CONFIG (

    call "%~dp0random_copy_push.bat" NOPAUSE

  ) else (

    call "%~dp0random_copy_push.bat" "!RCP_SOURCE!" NOPAUSE

  )

  if errorlevel 1 (

    echo random_copy_push.bat failed with code !ERRORLEVEL!.

    pause

    exit /b !ERRORLEVEL!

  )

  git add -- "!SNIP1!" "!SNIP2!"

  git diff --cached --quiet

  if errorlevel 1 (

    git commit -m "chore: append random snippets from external project (round %%i/%ITERATIONS%)"

    if errorlevel 1 (

      echo git commit failed. Configure user.name and user.email if needed.

      pause

      exit /b 1

    )

    git push origin HEAD

    if errorlevel 1 (

      echo git push failed. Check remote and credentials.

      pause

      exit /b 1

    )

    echo Round %%i: committed and pushed to origin.

  ) else (

    echo Round %%i: no changes in snippet files to commit.

  )

)



echo.

echo Done: completed %ITERATIONS% rounds.

pause

exit /b 0

