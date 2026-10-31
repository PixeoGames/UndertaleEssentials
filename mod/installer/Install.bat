@echo off
title Undertale Essentials - Install
rem You can also drag your Undertale folder onto this file.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\install.ps1" %*
echo.
pause
