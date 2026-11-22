@echo off
if not exist "%~dp0install.ps1" (
  echo.
  echo   Snachala RASPAKUJTE arhiv: pravaja knopka - "Izvlech vse",
  echo   potom zapustite Ustanovit.cmd iz raspakovannoj papki.
  echo.
  pause
  exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 pause
