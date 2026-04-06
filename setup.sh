#!/bin/bash
# Symlinks Claude Code config files from this repo to ~/.claude/
# Usage: bash setup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR"

ln -sf "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
ln -sf "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
ln -sf "$SCRIPT_DIR/notification-sound.sh" "$CLAUDE_DIR/notification-sound.sh"

touch "$CLAUDE_DIR/sound-enabled"
chmod +x "$SCRIPT_DIR/statusline.sh" "$SCRIPT_DIR/notification-sound.sh"

echo "Claude Code config linked successfully."
