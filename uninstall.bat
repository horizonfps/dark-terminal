@echo off
title Hellfire Terminal Uninstaller
echo.
echo  ========================================
echo   HELLFIRE TERMINAL - Uninstall
echo  ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$claudeSL = \"$env:USERPROFILE\.claude\statusline.sh\"; " ^
  "if (Test-Path \"$claudeSL.bak\") { Copy-Item \"$claudeSL.bak\" $claudeSL -Force; Write-Host '  Restored statusline backup' } " ^
  "elseif (Test-Path $claudeSL) { Remove-Item $claudeSL; Write-Host '  Removed statusline' }; " ^
  "$wtPaths = @(\"$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json\", \"$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json\"); " ^
  "foreach ($p in $wtPaths) { $bak = \"$p.bak\"; if (Test-Path $bak) { Copy-Item $bak $p -Force; Write-Host \"  Restored WT settings from backup\"; break } }; " ^
  "Write-Host ''; Write-Host '  Done. Restart Windows Terminal.'"

echo.
pause
