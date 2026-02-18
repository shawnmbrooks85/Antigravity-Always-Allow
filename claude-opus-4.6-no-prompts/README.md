# Claude Opus 4.6 No-Prompts Config Bundle

This bundle mirrors your Codex no-prompt setup for Claude in Antigravity.

## Files

- `antigravity-claude-settings.json`: Antigravity user settings for Claude no-prompt behavior
- `claude-code-settings.json`: Claude Code native settings (`.claude/settings.json`)

## What this enables

- Claude model set to `claude-opus-4.6-thinking`
- Permission mode set to bypass/no-prompt (`bypassPermissions` + `dontAsk`)
- Auto-execution and auto-apply behavior for Claude flow
- Global review-skip behavior:
  - `"antigravity.editor.confirmChanges": "never"`
  - `"antigravity.artifact.reviewPolicy": "alwaysProceed"`
  - `"antigravity.commands.autoExecute": true`
  - `"antigravity.edits.autoApply": true`
- `/tmp` support for Claude file operations via `permissions.additionalDirectories`

## Import on another Linux machine

1. Copy this folder to the target machine.
2. Merge Antigravity settings (recommended):

```bash
mkdir -p ~/.config/Antigravity/User
touch ~/.config/Antigravity/User/settings.json
jq -s '.[0] * .[1]' \
  ~/.config/Antigravity/User/settings.json \
  /path/to/claude-opus-4.6-no-prompts/antigravity-claude-settings.json \
  > ~/.config/Antigravity/User/settings.merged.json
mv ~/.config/Antigravity/User/settings.merged.json ~/.config/Antigravity/User/settings.json
```

3. Apply Claude Code native settings (project-level):

```bash
mkdir -p /path/to/your-project/.claude
cp /path/to/claude-opus-4.6-no-prompts/claude-code-settings.json \
  /path/to/your-project/.claude/settings.json
```

4. Reload Antigravity/VS Code window and start a new Claude conversation.

## Notes

- If your build uses a slightly different model ID, change:
  - `claudeCode.preferredModel`
  - `claudeCode.selectedModel`
  - `.claude/settings.json` -> `model`
- This disables approval prompts and should only be used on trusted machines/repos.
