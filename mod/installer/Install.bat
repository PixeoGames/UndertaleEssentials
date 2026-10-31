@echo off
rem Opens the installer window. You can also drag your Undertale folder onto this file.
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0files\setup.ps1" %*
