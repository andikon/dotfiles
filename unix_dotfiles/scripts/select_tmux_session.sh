#!/bin/bash

# Get list of sessions (quietly)
SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

# If no sessions exist, create one
if [ -z "$SESSIONS" ]; then
    echo "No tmux sessions found. Creating default session."
    exec tmux new -s main
fi

# Pick a session
SELECTED=$(printf '%s\n' "$SESSIONS" | fzf --prompt="Select tmux session: ")

# If fzf was cancelled, do nothing
if [ -z "$SELECTED" ]; then
    exit 0
fi

# create .curproj file
echo "$SELECTED" > /projects/.curproj


# If already inside tmux, switch client; otherwise attach
if [ -n "$TMUX" ]; then
    tmux switch-client -t "$SELECTED"
else
    exec tmux attach -t "$SELECTED"
fi
