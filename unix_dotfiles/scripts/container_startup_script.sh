#!/bin/bash
set -euo pipefail

export TERM="xterm-256color"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional custom cert injection
if [ -f /tmp/cert.pem ]; then
    CERT_DIR="/usr/local/share/ca-certificates"
    cp /tmp/cert.pem "$CERT_DIR/custom-cert.crt"
    update-ca-certificates
fi


"$SCRIPT_DIR/init_all_projects.sh"

exec "$SCRIPT_DIR/select_tmux_session.sh"
