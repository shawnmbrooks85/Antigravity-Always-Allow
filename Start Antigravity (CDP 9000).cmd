@echo off
setlocal
set "ELECTRON_RUN_AS_NODE="
taskkill /IM "Antigravity.exe" /F >nul 2>&1
timeout /t 1 /nobreak >nul
if exist "C:\Users\LabAdmin\AppData\Local\Programs\Antigravity\Antigravity.exe" (
  start "" "C:\Users\LabAdmin\AppData\Local\Programs\Antigravity\Antigravity.exe" --remote-debugging-port=9000
  exit /b 0
)
echo Unable to find executable: C:\Users\LabAdmin\AppData\Local\Programs\Antigravity\Antigravity.exe
exit /b 1