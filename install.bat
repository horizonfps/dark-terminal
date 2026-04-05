@echo off
title Hellfire Terminal Installer
echo.
echo  ========================================
echo   HELLFIRE TERMINAL - Dark Aesthetic
echo  ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

echo.
echo  Restart Windows Terminal to apply.
echo.
pause
