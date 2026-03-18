# Codex No-Prompts Config Bundle

This folder contains the config files needed to run Codex with no approval prompts.

## Files

- `codex-config.toml`: for `~/.codex/config.toml`
- `antigravity-settings.json`: Antigravity/IDE settings keys for no prompt permissions

## What this enables

- `approval_policy = "never"`
- `sandbox_mode = "danger-full-access"`
- Antigravity permissions set to `"defaultMode": "dontAsk"`
- Global auto-apply/review-skip behavior:
  - `"antigravity.editor.confirmChanges": "never"`
  - `"antigravity.artifact.reviewPolicy": "alwaysProceed"`
  - `"antigravity.commands.autoExecute": true`
  - `"antigravity.edits.autoApply": true`
- Current Antigravity preference migration source keys:
  - `"planningMode": 1` (`OFF`)
  - `"cascadeAutoExecutionPolicy": 3` (`EAGER`)
  - `"artifactReviewMode": 2` (`TURBO`)
- Direct agent preference keys:
  - `"terminalAutoExecutionPolicy": 3` (`EAGER`)
  - `"terminalAllowedCommands": []`
  - `"terminalDeniedCommands": []`
  - `"artifactReviewPolicy": 2` (`TURBO`)
  - `"cascadeAutoExecutionPolicy": 3` and `"terminalAutoExecutionPolicy": 3` (`EAGER`)
  - `"antigravity.commands.autoApprove": true` / `"antigravity.terminal.autoApprove": true`
  - `"antigravity.commands.confirmBeforeRun": false` / `"antigravity.terminal.confirmBeforeRun": false`

## Import on another Linux machine

1. Copy this folder to the target machine.
2. Apply Codex config:

```bash
mkdir -p ~/.codex
cp /path/to/codex-no-prompts/codex-config.toml ~/.codex/config.toml
```

3. Apply Antigravity settings.

Option A (replace full file):

```bash
mkdir -p ~/.config/Antigravity/User
cp /path/to/codex-no-prompts/antigravity-settings.json ~/.config/Antigravity/User/settings.json
```

Option B (merge with existing settings, recommended):

```bash
mkdir -p ~/.config/Antigravity/User
touch ~/.config/Antigravity/User/settings.json
jq -s '.[0] * .[1]' \
  ~/.config/Antigravity/User/settings.json \
  /path/to/codex-no-prompts/antigravity-settings.json \
  > ~/.config/Antigravity/User/settings.merged.json
mv ~/.config/Antigravity/User/settings.merged.json ~/.config/Antigravity/User/settings.json
```

4. Fully restart Antigravity and start a new Codex thread.

## Safety note

This disables approval prompts and sandboxing. Use only on trusted machines and trusted repos.
