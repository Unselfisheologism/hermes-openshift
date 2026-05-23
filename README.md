# Hermes Agent on OpenShift DevSpaces

## What This Is

A persistent cloud workspace for Hermes Agent, accessible from
your phone via Discord. Laptop can be off.

## Setup (do once, ~10 min)

### 1. Create an empty GitHub repo
  - Go to github.com → New repo → name it "hermes-workspace"
  - Initialize with a README
  - Add the devfile.yaml from this folder to the repo root

### 2. Open in DevSpaces
  - Go to https://workspaces.openshift.com
  - Create Workspace → Import from Git → paste your repo URL
  - Wait for workspace to start

### 3. In the workspace terminal, run:

  Install Hermes:
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

  Configure LLM provider:
    hermes setup model
    → Select: Custom Endpoint
    → Base URL: https://opengateway.gitlawb.com/v1
    → API Key: ogw_live_95e21418d8d8af90d36206f99b16d89c

  Configure Discord gateway:
    hermes setup gateway
    → Select Discord, follow prompts

  Start the gateway:
    tmux new-session -d -s hermes-gw
    tmux send-keys -t hermes-gw 'hermes gateway start' Enter

### 4. Message your Discord bot from your phone. Done.

## Daily Use

Just message your Discord bot. Examples:

  "Clone https://github.com/Unselfisheologism/Twent and fix issue #42"
  "Review the open PRs on operit"
  "What's the status of my repos?"

## Keeping It Alive

The devfile auto-starts a keepalive ping (every 2 min) to prevent
workspace hibernation. If it does hibernate, send a Discord message
and it should wake the workspace back up.

To manually check:
  tmux ls                    # see running sessions
  tmux attach -t hermes-gw   # view gateway logs
