@echo off
title Undertale Essentials - Uninstall
rem You can also drag your Undertale folder onto this file. (Install.bat's window can uninstall too.)
if not exist "%~dp0files\install.ps1" goto notunzipped
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\install.ps1" -Uninstall %*
echo.
pause
goto end
:notunzipped
echo The installer's files aren't next to Uninstall.bat. Unzip the whole download first
echo (right-click the zip file, then Extract All), then run Uninstall.bat from the unzipped folder.
echo.
pause
:end
