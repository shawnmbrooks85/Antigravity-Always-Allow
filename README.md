# Google Antigravity Always Allow

Portable config bundles for running Antigravity/Codex/Claude with minimal approval prompts.

## Auto Installer

Use `install.sh` to apply configs automatically with backup + merge behavior.

```bash
# Codex + Claude (default), writes .claude/settings.json in current directory
./install.sh --all

# Codex only
./install.sh --codex

# Claude only, target a specific project
./install.sh --claude --project ~/code/my-project
```

Use `--dry-run` to preview changes and `--replace` to replace Antigravity settings instead of merge.

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
