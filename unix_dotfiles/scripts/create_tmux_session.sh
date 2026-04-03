#!/bin/bash

# Usage: ./create_tmux_session.sh /path/to/project

PROJECT_DIR="$1"

if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: $0 /path/to/project"
    exit 1
fi

SESSION_NAME=$(basename "$PROJECT_DIR")

# Skip if session already exists
tmux has-session -t "$SESSION_NAME" 2>/dev/null
if [ $? == 0 ]; then
    echo "Session $SESSION_NAME already exists, skipping..."
    exit 0
fi

# Create session detached in the project folder
tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_DIR" -n editor

# Run nvim in the first window
tmux send-keys -t "$SESSION_NAME:editor" "nvim" C-m

# Create second window for terminal
tmux new-window -t "$SESSION_NAME" -n terminal -c "$PROJECT_DIR"

echo "Created tmux session '$SESSION_NAME'."
