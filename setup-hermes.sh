#!/bin/bash
# ================================================================
# Hermes Agent - OpenShift DevSpaces Quick Setup
# Run this script inside your DevSpaces workspace terminal
# ================================================================
set -e

echo "============================================"
echo "  HERMES AGENT - DEVSPACES SETUP"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ---- Step 1: Check environment ----
echo -e "${YELLOW}[1/6] Checking environment...${NC}"
echo "  Python: $(python3 --version 2>/dev/null || echo 'NOT FOUND')"
echo "  Home: $HOME"
echo "  HERMES_HOME: ${HERMES_HOME:-$HOME/.hermes}"

if [ -z "$DISCORD_BOT_TOKEN" ]; then
    echo -e "${RED}WARNING: DISCORD_BOT_TOKEN not set!${NC}"
    echo "  Set it in DevSpaces environment variables (Settings → Environment)"
    echo "  or export it manually:"
    echo "    export DISCORD_BOT_TOKEN='your-token-here'"
    echo ""
fi

# ---- Step 2: Install system dependencies ----
echo -e "${YELLOW}[2/6] Installing system dependencies...${NC}"
sudo dnf install -y python3-pip python3-devel gcc tmux git curl jq 2>/dev/null || \
sudo apt-get update && sudo apt-get install -y python3-pip python3-dev gcc tmux git curl jq 2>/dev/null || \
echo "  (package install skipped - may already be present)"

# Install GitHub CLI (for PR creation, issue management, code review)
if ! command -v gh &>/dev/null; then
    echo "  Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture 2>/dev/null || echo amd64) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null 2>/dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq gh 2>/dev/null || \
    sudo dnf install -y gh 2>/dev/null || \
    echo "  (gh CLI install failed - Hermes can still use git directly)"
fi

# ---- Step 2b: Configure Git auth ----
echo -e "${YELLOW}[2b] Configuring Git authentication...${NC}"
if [ -n "$GITHUB_TOKEN" ]; then
    # Use GitHub Personal Access Token (PAT)
    git config --global credential.helper store
    echo "https://Unselfisheologism:${GITHUB_TOKEN}@github.com" > "$HOME/.git-credentials"
    chmod 600 "$HOME/.git-credentials"
    git config --global user.name "Unselfisheologism"
    git config --global user.email "jeffrin@example.com"
    echo -e "  ${GREEN}Git auth configured with GitHub PAT${NC}"
    # Also authenticate gh CLI for PR/issue operations
    if command -v gh &>/dev/null; then
        echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null
        echo -e "  ${GREEN}gh CLI authenticated${NC}"
    fi
elif [ -n "$GITHUB_SSH_KEY" ]; then
    # Use SSH key (base64-encoded private key passed as env var)
    mkdir -p "$HOME/.ssh"
    echo "$GITHUB_SSH_KEY" | base64 -d > "$HOME/.ssh/id_ed25519"
    chmod 600 "$HOME/.ssh/id_ed25519"
    ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    git config --global core.sshCommand "ssh -i $HOME/.ssh/id_ed25519"
    git config --global user.name "Unselfisheologism"
    git config --global user.email "jeffrin@example.com"
    echo -e "  ${GREEN}Git auth configured with SSH key${NC}"
else
    echo -e "  ${YELLOW}No GITHUB_TOKEN or GITHUB_SSH_KEY set.${NC}"
    echo "  Set one in DevSpaces environment variables:"
    echo "    GITHUB_TOKEN = your GitHub Personal Access Token"
    echo "    (Settings → Environment Variables in DevSpaces)"
    echo ""
    echo "  To create a PAT: GitHub → Settings → Developer Settings"
    echo "  → Personal Access Tokens → Generate new token"
    echo "  → Select scopes: repo, workflow, read:org"
fi

# ---- Step 3: Install Hermes Agent ----
echo -e "${YELLOW}[3/6] Installing Hermes Agent...${NC}"
if [ -f "$HOME/.hermes/hermes-agent/cli.py" ]; then
    echo "  Hermes already installed, updating..."
    cd "$HOME/.hermes/hermes-agent" && git pull 2>/dev/null || true
else
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
fi

# Make hermes command available
export PATH="$HOME/.hermes/hermes-agent/venv/bin:$HOME/.local/bin:$PATH"
if ! command -v hermes &>/dev/null; then
    echo -e "${RED}ERROR: hermes command not found after install${NC}"
    echo "  Try: cd ~/.hermes/hermes-agent && pip install -e ."
    exit 1
fi
echo "  $(hermes --version 2>&1 | head -1)"

# ---- Step 4: Configure Hermes ----
echo -e "${YELLOW}[4/6] Configuring Hermes...${NC}"
mkdir -p "$HOME/.hermes"

cat > "$HOME/.hermes/config.yaml" << 'EOF'
model:
  default: "anthropic/claude-sonnet-4"
  provider: "custom"
  base_url: "https://opengateway.gitlawb.com/v1"
  api_key: "ogw_live_95e21418d8d8af90d36206f99b16d89c"

terminal:
  backend: local
  timeout: 180

agent:
  max_turns: 90

compression:
  enabled: true
  threshold: 0.50
  target_ratio: 0.20

display:
  skin: dark
  tool_progress: true
  show_cost: false

memory:
  memory_enabled: true
  user_profile_enabled: true

delegation:
  max_concurrent_children: 3
EOF

cat > "$HOME/.hermes/.env" << EOF
OPENROUTER_API_KEY=ogw_live_95e21418d8d8af90d36206f99b16d89c
HERMES_DEFAULT_PROVIDER=custom
HERMES_BASE_URL=https://opengateway.gitlawb.com/v1
${DISCORD_BOT_TOKEN:+DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN}
EOF
chmod 600 "$HOME/.hermes/.env"

echo "  Config written to ~/.hermes/config.yaml"
echo "  Env written to ~/.hermes/.env"

# ---- Step 5: Configure Discord Gateway ----
echo -e "${YELLOW}[5/6] Configuring Discord gateway...${NC}"
if [ -n "$DISCORD_BOT_TOKEN" ]; then
    hermes gateway setup 2>/dev/null || {
        echo "  (interactive setup skipped - configuring manually)"
        # Add discord config
        python3 -c "
import yaml
with open('$HOME/.hermes/config.yaml') as f:
    cfg = yaml.safe_load(f)
cfg['gateway'] = {'platforms': {'discord': {'enabled': True, 'token': '$DISCORD_BOT_TOKEN'}}}
with open('$HOME/.hermes/config.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
" 2>/dev/null || echo "  (manual config needed - see below)"
    }
    echo -e "  ${GREEN}Discord gateway configured${NC}"
else
    echo -e "  ${RED}Skipped - set DISCORD_BOT_TOKEN first${NC}"
fi

# ---- Step 6: Start the gateway ----
echo -e "${YELLOW}[6/6] Starting Hermes Discord gateway...${NC}"

# Kill any existing session
tmux kill-session -t hermes-gw 2>/dev/null || true

# Start fresh
tmux new-session -d -s hermes-gw -x 120 -y 40
tmux send-keys -t hermes-gw "export PATH=\"$HOME/.hermes/hermes-agent/venv/bin:\$PATH\"" Enter
tmux send-keys -t hermes-gw "cd $HOME/.hermes/hermes-agent 2>/dev/null || true" Enter
tmux send-keys -t hermes-gw "hermes gateway run" Enter

sleep 3

# Check if it's running
if tmux list-sessions 2>/dev/null | grep -q hermes-gw; then
    echo -e "  ${GREEN}Gateway running in tmux session 'hermes-gw'${NC}"
else
    echo -e "  ${RED}Gateway may have failed - check: tmux attach -t hermes-gw${NC}"
fi

# ---- Done ----
echo ""
echo "============================================"
echo -e "  ${GREEN}SETUP COMPLETE!${NC}"
echo "============================================"
echo ""
echo "  Hermes is running with Discord gateway."
echo "  Message your Discord bot to talk to Hermes!"
echo ""
echo "  Useful commands:"
echo "    tmux attach -t hermes-gw     # view gateway logs"
echo "    tmux kill-session -t hermes-gw  # stop gateway"
echo "    hermes status                # check status"
echo "    hermes gateway restart       # restart gateway"
echo ""
echo "  Anti-hibernation: auto-started via devfile postStart"
echo ""
