@echo off
setlocal
set "SCRIPT=%~dp0..\folder-snapshot.ps1"
if not exist "%SCRIPT%" (
  echo.
  echo Script not found at:
  echo   %SCRIPT%
  echo Place folder-snapshot.ps1 one level above this file.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Path "%~dp0." -All
echo.
pause
