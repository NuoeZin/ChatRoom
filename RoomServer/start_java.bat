@echo off
chcp 65001 >nul
cd /d "%~dp0java"

rem 没有编译产物时，用系统 JDK 重新编译（必须指定 UTF-8）
if not exist "Server.class" (
    javac -encoding UTF-8 Server.java
)

if exist "..\Runtime\bin\java.exe" (
    "..\Runtime\bin\java.exe" -cp . Server %*
) else (
    java -cp . Server %*
)
pause
