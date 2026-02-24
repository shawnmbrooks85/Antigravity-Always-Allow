[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Codex,
    [switch]$Claude,
    [string]$Project = (Get-Location).Path,
    [switch]$Replace,
    [switch]$DryRun,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Show-Usage {
    @"
Usage: .\install.ps1 [-All|-Codex|-Claude] [-Project PATH] [-Replace] [-DryRun]

Options:
  -All       Install Codex + Claude settings (default)
  -Codex     Install Codex settings only
  -Claude    Install Claude settings only
  -Project   Target project for .claude/settings.json (default: current directory)
  -Replace   Replace Antigravity settings file instead of merge
  -DryRun    Print actions without writing files
  -Help      Show this help

Examples:
  .\install.ps1 -All -Project C:\code\my-repo
  .\install.ps1 -Codex
  .\install.ps1 -Claude -Project C:\code\my-repo
"@
}

function Write-Log {
    param([string]$Message)
    Write-Host $Message
}

function Backup-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$Path.bak.$timestamp"
    if ($DryRun) {
        Write-Log "[dry-run] backup $Path -> $backupPath"
        return
    }

    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    Write-Log "Backed up: $backupPath"
}

function Copy-File {
    param(
        [string]$Source,
        [string]$Destination
    )

    $destinationDir = [System.IO.Path]::GetDirectoryName($Destination)
    if ($DryRun) {
        Write-Log "[dry-run] mkdir -p $destinationDir"
        Write-Log "[dry-run] copy $Source -> $Destination"
        return
    }

    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Log "Wrote: $Destination"
}

function Convert-ToMergeObject {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $Value.Keys) {
            $result[[string]$key] = Convert-ToMergeObject $Value[$key]
        }
        return $result
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $result = @{}
        foreach ($prop in $Value.PSObject.Properties) {
            $result[$prop.Name] = Convert-ToMergeObject $prop.Value
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @($Value | ForEach-Object { Convert-ToMergeObject $_ })
        return ,$items
    }

    return $Value
}

function Normalize-JsonText {
    param([string]$JsonText)

    $withoutBlockComments = [regex]::Replace($JsonText, "/\*[\s\S]*?\*/", "")
    $withoutLineComments = [regex]::Replace($withoutBlockComments, "(?m)^\s*//.*$", "")
    $withoutTrailingCommas = [regex]::Replace($withoutLineComments, ",(\s*[}\]])", '$1')
    return $withoutTrailingCommas
}

function Parse-JsonLikeFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{}
    }

    $raw = Get-Content -Raw -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{}
    }

    try {
        return Convert-ToMergeObject ($raw | ConvertFrom-Json)
    } catch {
        $normalized = Normalize-JsonText $raw
        return Convert-ToMergeObject ($normalized | ConvertFrom-Json)
    }
}

function Merge-Hashtable {
    param(
        [hashtable]$Base,
        [hashtable]$Overlay
    )

    foreach ($key in $Overlay.Keys) {
        $overlayValue = $Overlay[$key]
        if (
            $Base.ContainsKey($key) -and
            ($Base[$key] -is [hashtable]) -and
            ($overlayValue -is [hashtable])
        ) {
            Merge-Hashtable -Base $Base[$key] -Overlay $overlayValue | Out-Null
            continue
        }

        $Base[$key] = $overlayValue
    }

    return $Base
}

function Write-TextFileWithRetry {
    param(
        [string]$Path,
        [string]$Content
    )

    $attempts = 12
    for ($i = 1; $i -le $attempts; $i++) {
        try {
            $Content | Set-Content -LiteralPath $Path -Encoding utf8
            return
        } catch [System.IO.IOException] {
            if ($i -ge $attempts) {
                throw
            }
            Start-Sleep -Milliseconds 250
        }
    }
}

function Merge-JsonIntoFile {
    param(
        [string]$BaseFile,
        [string]$OverlayFile
    )

    if ($Replace) {
        Backup-File -Path $BaseFile
        Copy-File -Source $OverlayFile -Destination $BaseFile
        return
    }

    if ($DryRun) {
        Write-Log "[dry-run] merge JSON: $BaseFile + $OverlayFile"
        return
    }

    $baseDir = [System.IO.Path]::GetDirectoryName($BaseFile)
    if (-not (Test-Path -LiteralPath $baseDir)) {
        New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $BaseFile -PathType Leaf)) {
        Write-TextFileWithRetry -Path $BaseFile -Content "{}"
    }

    Backup-File -Path $BaseFile
    $baseObj = Parse-JsonLikeFile -Path $BaseFile
    $overlayObj = Parse-JsonLikeFile -Path $OverlayFile
    $merged = Merge-Hashtable -Base $baseObj -Overlay $overlayObj
    Write-TextFileWithRetry -Path $BaseFile -Content ($merged | ConvertTo-Json -Depth 100)
    Write-Log "Merged: $BaseFile"
}

function Reset-AgentPreferenceMigrationFlags {
    param([string]$StorageFile)

    if ($DryRun) {
        Write-Log "[dry-run] reset one-time agent preference migration flags in $StorageFile"
        return
    }

    if (-not (Test-Path -LiteralPath $StorageFile -PathType Leaf)) {
        return
    }

    Backup-File -Path $StorageFile
    $storage = Parse-JsonLikeFile -Path $StorageFile

    $storage["antigravityUnifiedStateSync.agentPreferences.hasPlanningModeMigrated"] = $false
    $storage["antigravityUnifiedStateSync.agentPreferences.hasArtifactReviewPolicyMigrated"] = $false
    $storage["antigravityUnifiedStateSync.agentPreferences.hasTerminalAutoExecutionPolicyMigrated"] = $false
    $storage["antigravityUnifiedStateSync.agentPreferences.hasTerminalAllowedCommandsMigrated"] = $false
    $storage["antigravityUnifiedStateSync.agentPreferences.hasTerminalDeniedCommandsMigrated"] = $false
    $storage["antigravityUnifiedStateSync.agentPreferences.hasAgentFileAccessMigration"] = $false
    $storage["antigravityUnifiedStateSync.agentPreferences.hasExplainAndFixInCurrentConversationMigrated"] = $false
    $storage["antigravityUnifiedStateSync.agentPreferences.hasAutoContinueOnMaxGeneratorInvocationsMigrated"] = $false

    Write-TextFileWithRetry -Path $StorageFile -Content ($storage | ConvertTo-Json -Depth 100)
    Write-Log "Updated: $StorageFile (agent preference migration flags reset)"
}

if ($Help) {
    Show-Usage
    exit 0
}

$selectedModes = @()
if ($All) { $selectedModes += "all" }
if ($Codex) { $selectedModes += "codex" }
if ($Claude) { $selectedModes += "claude" }
if ($selectedModes.Count -gt 1) {
    throw "Choose only one of: -All, -Codex, -Claude"
}
$Mode = if ($selectedModes.Count -eq 0) { "all" } else { $selectedModes[0] }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$codexTomlSrc = Join-Path $scriptDir "codex-no-prompts\codex-config.toml"
$codexAgSettingsSrc = Join-Path $scriptDir "codex-no-prompts\antigravity-settings.json"
$claudeAgSettingsSrc = Join-Path $scriptDir "claude-opus-4.6-no-prompts\antigravity-claude-settings.json"
$claudeProjectSettingsSrc = Join-Path $scriptDir "claude-opus-4.6-no-prompts\claude-code-settings.json"

$codexTomlDst = Join-Path $env:USERPROFILE ".codex\config.toml"
$agUserDir = Join-Path $env:APPDATA "Antigravity\User"
$agSettingsDst = Join-Path $agUserDir "settings.json"
$agStorageDst = Join-Path $agUserDir "globalStorage\storage.json"
$claudeProjectSettingsDst = Join-Path $Project ".claude\settings.json"
$claudeGlobalSettingsDst = Join-Path $env:USERPROFILE ".claude\settings.json"

foreach ($requiredFile in @($codexTomlSrc, $codexAgSettingsSrc, $claudeAgSettingsSrc, $claudeProjectSettingsSrc)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Missing file: $requiredFile"
    }
}

$didTouchAgSettings = $false

function Apply-Codex {
    Write-Log ""
    Write-Log "Applying Codex settings..."
    Backup-File -Path $codexTomlDst
    Copy-File -Source $codexTomlSrc -Destination $codexTomlDst
    Merge-JsonIntoFile -BaseFile $agSettingsDst -OverlayFile $codexAgSettingsSrc
    $script:didTouchAgSettings = $true
}

function Apply-Claude {
    Write-Log ""
    Write-Log "Applying Claude settings..."
    Merge-JsonIntoFile -BaseFile $agSettingsDst -OverlayFile $claudeAgSettingsSrc
    $script:didTouchAgSettings = $true
    Backup-File -Path $claudeGlobalSettingsDst
    Copy-File -Source $claudeProjectSettingsSrc -Destination $claudeGlobalSettingsDst
    Backup-File -Path $claudeProjectSettingsDst
    Copy-File -Source $claudeProjectSettingsSrc -Destination $claudeProjectSettingsDst
}

switch ($Mode) {
    "codex" { Apply-Codex; break }
    "claude" { Apply-Claude; break }
    default { Apply-Codex; Apply-Claude; break }
}

if ($didTouchAgSettings) {
    Reset-AgentPreferenceMigrationFlags -StorageFile $agStorageDst
}

Write-Log ""
if ($DryRun) {
    Write-Log "Dry run complete. No files were changed."
} else {
    Write-Log "Done. Fully restart Antigravity/VS Code and start a new conversation."
}
