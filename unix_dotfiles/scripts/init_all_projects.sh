#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="/projects"

for dir in "$PROJECTS_DIR"/*; do
   	"$SCRIPT_DIR/create_tmux_session.sh" "$dir"
done

echo "All projects processed."
