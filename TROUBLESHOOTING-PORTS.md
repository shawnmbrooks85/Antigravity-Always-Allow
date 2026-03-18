# Port Conflict Troubleshooting

## Problem

Antigravity uses Chrome DevTools Protocol (CDP) on `--remote-debugging-port` (default **9000**) for the auto-accept extension to communicate with the browser. If another process is already listening on that port, Antigravity will silently fail to open the debug port and auto-accept will stop working.

## Known Conflict: MECM Console (Microsoft Endpoint Configuration Manager)

The **MECM / SCCM admin console** (`Microsoft.ConfigurationManagement.exe`) and related services (`sccmprovidergraph`, `smsexec`, etc.) have been observed to intermittently bind to ports **9000** and **9222**.

### Related Processes

| Process Name | Description |
|---|---|
| `Microsoft.ConfigurationManagement` | MECM Console UI |
| `sccmprovidergraph` | SCCM Provider Graph service |
| `smsexec` | SMS Executive service |
| `smssqlbkup` | SMS SQL Backup |
| `smswriter` | SMS Writer (VSS) |

### Symptoms
- Auto-accept extension stops clicking/accepting
- Port 9000 or 9222 is `LISTENING` under a non-Antigravity PID
- Antigravity launches but CDP connection fails silently

## Diagnosis Commands

### Check which process holds the port
```powershell
# Check if port 9000 or 9222 is in use
netstat -ano | Select-String "LISTENING" | Select-String ":9000|:9222"

# Identify the process by PID (replace <PID> with the number from above)
Get-Process -Id <PID> | Select-Object Id, ProcessName, Path
```

### Check if MECM is running
```powershell
Get-Process | Where-Object { $_.ProcessName -match "SMS|SCCM|MECM|ConfigMgr|AdminConsole|Microsoft.ConfigurationManagement" } | Select-Object Id, ProcessName | Format-Table -AutoSize
```

## Fix

1. **Close the MECM console** before launching Antigravity, or
2. **Use the updated launcher** `Start Antigravity (CDP 9000).cmd` which now auto-detects port conflicts and picks an available port, or
3. **Manually specify a different port**:
   ```cmd
   "C:\Users\LabAdmin\AppData\Local\Programs\Antigravity\Antigravity.exe" --remote-debugging-port=9333
   ```

## Investigation Log (2026-03-18)

- **Port 9000**: Held by Antigravity.exe (PID 16036) ✅
- **Port 9222**: Held by Chrome.exe (PID 14928) ✅
- **MECM Console**: Running (PID 15996) but NOT occupying either port at time of check
- **Conclusion**: Conflict is intermittent — MECM may grab ports during certain operations then release them
