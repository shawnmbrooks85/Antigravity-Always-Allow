# Google Antigravity Always Allow

Portable config bundles for running Antigravity/Codex/Claude with minimal approval prompts.

## Auto Installer

Use the installer for your shell to apply configs with backup + merge behavior.

### Bash (`install.sh`)

```bash
# Codex + Claude (default), writes .claude/settings.json in current directory
./install.sh --all

# Codex only
./install.sh --codex

# Claude only, target a specific project
./install.sh --claude --project ~/code/my-project
```

### PowerShell on Windows (`install.ps1`)

```powershell
# Codex + Claude (default), writes .claude/settings.json in current directory
.\install.ps1 -All

# Codex only
.\install.ps1 -Codex

# Claude only, target a specific project
.\install.ps1 -Claude -Project C:\code\my-project
```

Use `--dry-run` to preview changes and `--replace` to replace Antigravity settings instead of merge.
Use `-DryRun` and `-Replace` with `install.ps1`.

Installer note: after applying Antigravity settings, the installer resets one-time agent preference migration flags in Antigravity `globalStorage/storage.json` so current Antigravity builds re-import no-prompt preferences on next app restart.

## Included Bundles

- `codex-no-prompts/`
  - Codex config (`~/.codex/config.toml`) with:
    - `approval_policy = "never"`
    - `sandbox_mode = "danger-full-access"`
  - Antigravity permission settings for no-prompt behavior

- `claude-opus-4.6-no-prompts/`
  - Antigravity Claude settings for:
    - `claude-opus-4.6-thinking`
    - bypass permissions mode and auto-exec flow
  - Claude native settings template for `.claude/settings.json`

## Quick Start

1. Pick the bundle you want.
2. Follow that bundle's `README.md`.
3. Reload Antigravity/VS Code and start a new conversation.

## Security Warning

These settings reduce or disable approval prompts and sandboxing. Use only on trusted machines and trusted repositories.
