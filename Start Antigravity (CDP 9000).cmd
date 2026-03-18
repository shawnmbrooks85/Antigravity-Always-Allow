@echo off
setlocal enabledelayedexpansion
set "ELECTRON_RUN_AS_NODE="

set "ANTIGRAVITY_EXE=C:\Users\LabAdmin\AppData\Local\Programs\Antigravity\Antigravity.exe"
if not exist "%ANTIGRAVITY_EXE%" (
  echo Unable to find executable: %ANTIGRAVITY_EXE%
  exit /b 1
)

taskkill /IM "Antigravity.exe" /F >nul 2>&1
timeout /t 1 /nobreak >nul

rem --- Port conflict detection ---
rem Try preferred ports in order; pick the first one that is free.
set "CDP_PORT="
for %%P in (9000 9222 9333 9444) do (
  if not defined CDP_PORT (
    netstat -ano | findstr "LISTENING" | findstr ":%%P " >nul 2>&1
    if errorlevel 1 (
      set "CDP_PORT=%%P"
    ) else (
      echo Port %%P is already in use, trying next...
    )
  )
)

if not defined CDP_PORT (
  echo ERROR: All preferred CDP ports (9000, 9222, 9333, 9444) are in use.
  echo See TROUBLESHOOTING-PORTS.md for diagnosis steps.
  pause
  exit /b 1
)

echo Starting Antigravity with CDP on port %CDP_PORT%...
start "" "%ANTIGRAVITY_EXE%" --remote-debugging-port=%CDP_PORT%
exit /b 0