@echo off
chcp 65001 >nul
cd /d "%~dp0python"

where python >nul 2>nul
if errorlevel 1 (
    py -3 server.py %*
) else (
    python server.py %*
)
pause
