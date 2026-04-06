#!/bin/bash
# Plays a notification sound and shows a macOS notification when Claude needs attention.
# Usage: bash notification-sound.sh [stop|permission|question]
# Toggle: touch ~/.claude/sound-enabled (on) / rm ~/.claude/sound-enabled (off)

if [ -f "$HOME/.claude/sound-enabled" ]; then
    case "${1:-stop}" in
        permission) MSG="Claude necesita tu permiso" ;;
        question)   MSG="Claude te esta preguntando algo" ;;
        *)          MSG="Claude termino su tarea" ;;
    esac

    afplay /System/Library/Sounds/Submarine.aiff &
    osascript -e "display notification \"$MSG\" with title \"Claude Code\"" &
fi
