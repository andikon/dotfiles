#!/usr/bin/env bash
set -euo pipefail


PROJECTS_DIR="$HOME/projects"

for dir in "$PROJECTS_DIR"/*; do
   	"create_tmux_session.sh" "$dir"
done

echo "All projects processed."
