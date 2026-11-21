@echo off
chcp 65001 >nul
cd /d "%~dp0java"

where javac >nul 2>nul
if not errorlevel 1 (
    javac -encoding UTF-8 Server.java SelfTest.java
)

if exist "..\Runtime\bin\java.exe" (
    "..\Runtime\bin\java.exe" -cp . SelfTest
) else (
    java -cp . SelfTest
)
pause
