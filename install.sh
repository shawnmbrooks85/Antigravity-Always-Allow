#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [--all|--codex|--claude] [--project PATH] [--replace] [--dry-run]

Options:
  --all            Install Codex + Claude settings (default)
  --codex          Install Codex settings only
  --claude         Install Claude settings only
  --project PATH   Target project for .claude/settings.json (default: current directory)
  --replace        Replace Antigravity settings file instead of merge
  --dry-run        Print actions without writing files
  -h, --help       Show this help

Examples:
  ./install.sh --all --project ~/code/my-repo
  ./install.sh --codex
  ./install.sh --claude --project ~/code/my-repo

Tip:
  On native Windows PowerShell, prefer install.ps1.
EOF
}

log() {
  printf '%s\n' "$*"
}

need_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "Missing required command: $cmd"
    exit 1
  fi
}

normalize_path_for_bash() {
  local path="$1"

  # Convert Windows-style env paths when running in Git Bash/MSYS.
  if [[ "$path" =~ ^[A-Za-z]:\\ ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$path"
    return
  fi

  printf '%s' "$path"
}

detect_antigravity_user_dir() {
  if [[ -n "${ANTIGRAVITY_USER_DIR:-}" ]]; then
    printf '%s' "$ANTIGRAVITY_USER_DIR"
    return
  fi

  # Prefer APPDATA on Windows (Git Bash/MSYS), fall back to ~/.config on Unix.
  if [[ -n "${APPDATA:-}" ]]; then
    local appdata
    appdata="$(normalize_path_for_bash "$APPDATA")"
    printf '%s' "$appdata/Antigravity/User"
    return
  fi

  printf '%s' "$HOME/.config/Antigravity/User"
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local bak="${file}.bak.${ts}"
    if [[ "$DRY_RUN" == "1" ]]; then
      log "[dry-run] backup $file -> $bak"
    else
      cp "$file" "$bak"
      log "Backed up: $bak"
    fi
  fi
}

copy_file() {
  local src="$1"
  local dst="$2"
  local dst_dir
  dst_dir="$(dirname "$dst")"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] mkdir -p $dst_dir"
    log "[dry-run] copy $src -> $dst"
    return
  fi

  mkdir -p "$dst_dir"
  cp "$src" "$dst"
  log "Wrote: $dst"
}

reset_agent_preference_migration_flags() {
  local storage_file="$AG_STORAGE_DST"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] reset one-time agent preference migration flags in $storage_file"
    return
  fi

  if [[ ! -f "$storage_file" ]]; then
    return
  fi

  need_cmd jq

  local tmp_file
  tmp_file="$(mktemp)"

  backup_file "$storage_file"
  jq '
    ."antigravityUnifiedStateSync.agentPreferences.hasPlanningModeMigrated" = false |
    ."antigravityUnifiedStateSync.agentPreferences.hasArtifactReviewPolicyMigrated" = false |
    ."antigravityUnifiedStateSync.agentPreferences.hasTerminalAutoExecutionPolicyMigrated" = false |
    ."antigravityUnifiedStateSync.agentPreferences.hasTerminalAllowedCommandsMigrated" = false |
    ."antigravityUnifiedStateSync.agentPreferences.hasTerminalDeniedCommandsMigrated" = false |
    ."antigravityUnifiedStateSync.agentPreferences.hasAgentFileAccessMigration" = false |
    ."antigravityUnifiedStateSync.agentPreferences.hasExplainAndFixInCurrentConversationMigrated" = false |
    ."antigravityUnifiedStateSync.agentPreferences.hasAutoContinueOnMaxGeneratorInvocationsMigrated" = false
  ' "$storage_file" >"$tmp_file"
  mv "$tmp_file" "$storage_file"
  log "Updated: $storage_file (agent preference migration flags reset)"
}

merge_json_into_file() {
  local base_file="$1"
  local overlay_file="$2"

  if [[ "$REPLACE" == "1" ]]; then
    backup_file "$base_file"
    copy_file "$overlay_file" "$base_file"
    return
  fi

  need_cmd jq

  normalize_json_for_merge() {
    local src="$1"
    local dst="$2"

    # Accept strict JSON first.
    if jq -e . "$src" >/dev/null 2>&1; then
      cp "$src" "$dst"
      return 0
    fi

    # Fallback for VS Code JSONC (block comments, line comments, trailing commas).
    perl -0777 -pe 's#/\*.*?\*/##gs; s#^\s*//.*$##gm; s#,(\s*[}\]])#\1#g' "$src" >"$dst"

    if ! jq -e . "$dst" >/dev/null 2>&1; then
      log "Failed to parse JSON/JSONC: $src"
      return 1
    fi
  }

  local tmp_file
  local normalized_base
  tmp_file="$(mktemp)"
  normalized_base="$(mktemp)"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] merge JSON: $base_file + $overlay_file"
    rm -f "$tmp_file"
    rm -f "$normalized_base"
    return
  fi

  mkdir -p "$(dirname "$base_file")"
  if [[ ! -f "$base_file" ]]; then
    printf '{}' >"$base_file"
  fi

  backup_file "$base_file"
  normalize_json_for_merge "$base_file" "$normalized_base" || {
    rm -f "$tmp_file" "$normalized_base"
    return 1
  }
  jq -s '.[0] * .[1]' "$normalized_base" "$overlay_file" >"$tmp_file"
  mv "$tmp_file" "$base_file"
  rm -f "$normalized_base"
  log "Merged: $base_file"
}

MODE="all"
PROJECT_DIR="$(pwd)"
REPLACE="0"
DRY_RUN="0"
DID_TOUCH_AG_SETTINGS="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --codex)
      MODE="codex"
      shift
      ;;
    --claude)
      MODE="claude"
      shift
      ;;
    --project)
      PROJECT_DIR="${2:-}"
      if [[ -z "$PROJECT_DIR" ]]; then
        log "--project requires a path"
        exit 1
      fi
      shift 2
      ;;
    --replace)
      REPLACE="1"
      shift
      ;;
    --dry-run)
      DRY_RUN="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CODEX_TOML_SRC="$SCRIPT_DIR/codex-no-prompts/codex-config.toml"
CODEX_AG_SETTINGS_SRC="$SCRIPT_DIR/codex-no-prompts/antigravity-settings.json"
CLAUDE_AG_SETTINGS_SRC="$SCRIPT_DIR/claude-opus-4.6-no-prompts/antigravity-claude-settings.json"
CLAUDE_PROJECT_SETTINGS_SRC="$SCRIPT_DIR/claude-opus-4.6-no-prompts/claude-code-settings.json"
AG_USER_DIR="$(detect_antigravity_user_dir)"

CODEX_TOML_DST="$HOME/.codex/config.toml"
AG_SETTINGS_DST="$AG_USER_DIR/settings.json"
AG_STORAGE_DST="$AG_USER_DIR/globalStorage/storage.json"
CLAUDE_PROJECT_SETTINGS_DST="$PROJECT_DIR/.claude/settings.json"
CLAUDE_GLOBAL_SETTINGS_DST="$HOME/.claude/settings.json"

[[ -f "$CODEX_TOML_SRC" ]] || { log "Missing file: $CODEX_TOML_SRC"; exit 1; }
[[ -f "$CODEX_AG_SETTINGS_SRC" ]] || { log "Missing file: $CODEX_AG_SETTINGS_SRC"; exit 1; }
[[ -f "$CLAUDE_AG_SETTINGS_SRC" ]] || { log "Missing file: $CLAUDE_AG_SETTINGS_SRC"; exit 1; }
[[ -f "$CLAUDE_PROJECT_SETTINGS_SRC" ]] || { log "Missing file: $CLAUDE_PROJECT_SETTINGS_SRC"; exit 1; }

apply_codex() {
  log ""
  log "Applying Codex settings..."
  backup_file "$CODEX_TOML_DST"
  copy_file "$CODEX_TOML_SRC" "$CODEX_TOML_DST"
  merge_json_into_file "$AG_SETTINGS_DST" "$CODEX_AG_SETTINGS_SRC"
  DID_TOUCH_AG_SETTINGS="1"
}

apply_claude() {
  log ""
  log "Applying Claude settings..."
  merge_json_into_file "$AG_SETTINGS_DST" "$CLAUDE_AG_SETTINGS_SRC"
  DID_TOUCH_AG_SETTINGS="1"
  backup_file "$CLAUDE_GLOBAL_SETTINGS_DST"
  copy_file "$CLAUDE_PROJECT_SETTINGS_SRC" "$CLAUDE_GLOBAL_SETTINGS_DST"
  backup_file "$CLAUDE_PROJECT_SETTINGS_DST"
  copy_file "$CLAUDE_PROJECT_SETTINGS_SRC" "$CLAUDE_PROJECT_SETTINGS_DST"
}

case "$MODE" in
  codex)
    apply_codex
    ;;
  claude)
    apply_claude
    ;;
  all)
    apply_codex
    apply_claude
    ;;
esac

if [[ "$DID_TOUCH_AG_SETTINGS" == "1" ]]; then
  reset_agent_preference_migration_flags
fi

log ""
if [[ "$DRY_RUN" == "1" ]]; then
  log "Dry run complete. No files were changed."
else
  log "Done. Fully restart Antigravity/VS Code and start a new conversation."
fi
