#!/usr/bin/env bash
set -euo pipefail

export TERM="xterm-256color"

# Optional custom cert injection
if [ -f /tmp/cert.pem ]; then
    CERT_DIR="/usr/local/share/ca-certificates"
    sudo cp /tmp/cert.pem "$CERT_DIR/custom-cert.crt"
    sudo update-ca-certificates
fi


"init_all_projects.sh"

exec "select_tmux_session.sh"
