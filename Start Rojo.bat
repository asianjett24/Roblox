@echo off
title Rojo - Castle Fishing
cd /d "%~dp0"
set ROJO=tools\rojo-7.7.0\rojo.exe
if not exist "%ROJO%" (
  echo Downloading Rojo 7.7.0 - one time only...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; New-Item -ItemType Directory -Force tools\rojo-7.7.0 | Out-Null; Invoke-WebRequest 'https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-windows-x86_64.zip' -OutFile 'tools\rojo.zip'; Expand-Archive -Force 'tools\rojo.zip' 'tools\rojo-7.7.0'; Remove-Item 'tools\rojo.zip'"
)
if not exist "%ROJO%" (
  echo Could not download Rojo. Check your internet connection and try again.
  pause
  exit /b 1
)
echo.
echo ============================================================
echo   Rojo is running!
echo   In Roblox Studio: open the Rojo plugin and click Connect.
echo   Keep this window open while you work. Close it to stop.
echo ============================================================
echo.
"%ROJO%" serve
pause
