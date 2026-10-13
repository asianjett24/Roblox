@echo off
title Rojo - Castle Fishing
cd /d "%~dp0"
if not exist "tools\rojo.exe" (
  echo Downloading Rojo - one time only...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; New-Item -ItemType Directory -Force tools | Out-Null; Invoke-WebRequest 'https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-windows-x86_64.zip' -OutFile 'tools\rojo.zip'; Expand-Archive -Force 'tools\rojo.zip' 'tools'; Remove-Item 'tools\rojo.zip'"
)
if not exist "tools\rojo.exe" (
  echo Could not download Rojo. Check your internet connection and try again.
  pause
  exit /b 1
)
"tools\rojo.exe" plugin install
echo.
echo ============================================================
echo   Rojo is running!
echo   In Roblox Studio: Plugins tab, click Rojo, then Connect.
echo   Keep this window open while you work. Close it to stop.
echo ============================================================
echo.
"tools\rojo.exe" serve
pause
