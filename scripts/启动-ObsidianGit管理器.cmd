@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT_DIR%obsidian-git-manager.ps1"
