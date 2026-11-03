@echo off
title Undertale Essentials - Install
rem Opens the installer window (files\setup.ps1). You can also drag your Undertale folder onto this file.
rem If the window can't start, it falls back to the same installer in this console window.
if not exist "%~dp0files\setup.ps1" goto notunzipped
if not exist "%~dp0files\install.ps1" goto notunzipped
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\setup.ps1" %*
if not errorlevel 1 goto end
echo.
echo The installer window couldn't start, or it stopped because of an error.
echo A log of what happened is in %TEMP%\UndertaleEssentials-installer.log
echo.
echo You can install from this window instead:
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\install.ps1" %*
echo.
pause
goto end
:notunzipped
echo The installer's files aren't next to Install.bat.
echo Unzip the whole download first (right-click the zip file, then Extract All),
echo then run Install.bat from the unzipped folder.
echo.
pause
:end
