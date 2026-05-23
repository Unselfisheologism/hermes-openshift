#!/bin/bash
# ================================================================
# Auto-restart Hermes gateway on workspace wake
# Runs via devfile postStart event and also as a cron fallback
# ================================================================

LOG="$HOME/.hermes/autostart.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
}

log "Workspace wake detected, checking Hermes..."

# Wait for workspace to fully initialize
sleep 15

# Check if gateway is already running
if tmux list-sessions 2>/dev/null | grep -q hermes-gw; then
    # Check if it's actually responsive (not just a dead tmux pane)
    if tmux capture-pane -t hermes-gw -p 2>/dev/null | grep -q "gateway\|Gateway\|running\|started\|Bot connected"; then
        log "Gateway already running and healthy"
        exit 0
    else
        log "Gateway tmux session exists but may be dead, restarting..."
        tmux kill-session -t hermes-gw 2>/dev/null
    fi
fi

# Start the gateway
log "Starting Hermes gateway..."
export PATH="$HOME/.hermes/hermes-agent/venv/bin:$HOME/.local/bin:$PATH"

tmux new-session -d -s hermes-gw -x 120 -y 40
tmux send-keys -t hermes-gw "export PATH=\"$HOME/.hermes/hermes-agent/venv/bin:\$PATH\"" Enter
tmux send-keys -t hermes-gw "cd $HOME/.hermes/hermes-agent 2>/dev/null || true" Enter
tmux send-keys -t hermes-gw "hermes gateway run" Enter

log "Gateway started in tmux session 'hermes-gw'"

# Also start keepalive if not running
if ! tmux list-sessions 2>/dev/null | grep -q keepalive; then
    tmux new-session -d -s keepalive
    tmux send-keys -t keepalive 'while true; do curl -s -o /dev/null -w "" https://console.redhat.com 2>/dev/null; sleep 120; done' Enter
    log "Keepalive started"
fi
