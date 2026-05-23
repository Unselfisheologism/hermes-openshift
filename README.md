# Hermes Agent on OpenShift DevSpaces — Setup Guide

## What This Does

Runs your Hermes Agent persistently in the cloud (OpenShift DevSpaces)
so you can access it from your phone via Discord — even when your
laptop is off.

```
Your Phone (Discord app)
  → Discord servers
    → Webhook → OpenShift DevSpaces workspace
      → Hermes Agent + Discord Gateway
        → Your LLM provider (OpenGateway)
        → All tools (terminal, file, web, skills)
```

## Prerequisites
- [x] OpenShift DevSpaces account
- [x] Discord bot token (from Discord Developer Portal)
- [x] OpenGateway API key
- [x] GitHub Personal Access Token (for git clone/push)

### Creating a GitHub PAT
  1. Go to: https://github.com/settings/tokens?type=beta
  2. Click "Generate new token"
  3. Name it: "hermes-devspaces"
  4. Set expiration: 90 days (renew when needed)
  5. Repository access: "All repositories" (or select specific ones)
  6. Permissions: Repository → Contents (Read/Write), Pull Requests (Read/Write), Issues (Read/Write)
  7. Generate and copy the token

## Setup Steps

### 1. Open OpenShift DevSpaces

Go to: https://workspaces.openshift.com
Log in with your Red Hat account.
Click "Create Workspace".

### 2. Import the devfile

When creating the workspace, choose "Import from Git" or use
"Devfile Location" and point to the raw devfile.yaml URL,
OR paste the devfile.yaml content directly.

Alternatively, after workspace opens:
  - Open terminal (Ctrl+` or Terminal menu)
  - Run: `vi devfile.yaml` and paste the content

### 3. Set Environment Variables

In DevSpaces:
  - Click the gear icon (⚙️) → User Settings
  - Or: File → Preferences → Settings → search "environment"
  - Add these environment variables:
      DISCORD_BOT_TOKEN = your-discord-bot-token
      GITHUB_TOKEN      = your-github-personal-access-token

Or in the terminal:
  ```bash
  export DISCORD_BOT_TOKEN='your-actual-token'
  export GITHUB_TOKEN='ghp_xxxxxxxxxxxxxxxxxxxx'
  ```

### 4. Run the Setup

In the workspace terminal:

```bash
chmod +x setup-hermes.sh
./setup-hermes.sh
```

This will:
  1. Install system dependencies (python, tmux, git, etc.)
  2. Install Hermes Agent
  3. Configure the OpenGateway LLM provider
  4. Set up Discord gateway
  5. Start the gateway in a tmux session

### 5. Verify

```bash
# Check gateway is running
tmux ls

# View gateway logs
tmux attach -t hermes-gw

# Should see: "Bot connected as YourBot#1234"
```

### 6. Talk to Hermes from Your Phone

Open the Discord app on your phone.
Find your bot in the server/DM.
Send a message!

## Working on GitHub Repos from Your Phone

Once setup is done, you message your Discord bot naturally:

  "Clone https://github.com/Unselfisheologism/Twent and look at the
   crash report in issue #42. Fix it and open a PR."

  "Review the open PRs on my operit repo and suggest improvements."

  "Create a new branch in Twent, add rate limiting to the API,
   write tests, and push."

Hermes will:
  1. `git clone` the repo (authenticated with your PAT)
  2. Create a branch, make changes, run tests
  3. Commit, push, and open a PR — all from the workspace

The repo persists in the workspace's storage between sessions.
You can also tell it to pull latest changes:

  "Pull the latest on Twent main branch and check if issue #38
   is still reproducible."

### Workspace File Layout

After setup, repos live alongside the Hermes home directory:

  /home/user/
  ├── .hermes/          # Hermes config, skills, memory
  ├── Twent/            # cloned repos live here
  ├── operit/
  └── any-other-repo/

Just tell Hermes the repo URL and what to do — it handles the rest.

## Keeping It Alive

OpenShift DevSpaces workspaces hibernate after ~4 hours of inactivity.
Three mechanisms prevent this:

1. **devfile postStart hook** — auto-starts a keepalive ping + gateway
   when workspace wakes up (built into devfile.yaml)

2. **Keepalive session** — pings every 2 minutes to prevent hibernation
   (started automatically)

3. **Hermes cron job** — optional, pings itself every 2 hours:
   ```bash
   hermes cron create "2h" -q "ping - just checking in"
   ```

If the workspace does hibernate:
  - Send a Discord message to your bot
  - OpenShift will wake the workspace (30-60s delay)
  - The autostart.sh script will restart the gateway
  - Hermes replies!

## Useful Commands

```bash
tmux attach -t hermes-gw      # View gateway live
tmux detach                     # Detach (Ctrl+B, then D)
tmux kill-session -t hermes-gw # Stop gateway

hermes gateway restart          # Restart gateway
hermes status                   # Check status
hermes sessions list            # List chat sessions
hermes tools list               # Show available tools

# One-shot queries from terminal
hermes chat -q "What is 2+2?"

# Interactive terminal session (in tmux)
tmux new-session -s chat
hermes
```

## Troubleshooting

**Gateway won't start:**
  - Check: `cat ~/.hermes/.env` — is DISCORD_BOT_TOKEN set?
  - Check: `hermes doctor`
  - Check: `tmux attach -t hermes-gw` for error messages

**Bot not responding in Discord:**
  - Is the gateway running? `tmux ls`
  - Check logs: `tail -50 ~/.hermes/logs/gateway.log`
  - Is the bot added to your Discord server?
  - Does the bot have Message Content Intent enabled?

**Workspace hibernated:**
  - It should auto-wake on Discord webhook
  - If not: open DevSpaces in browser → workspace wakes
  - Run: `./autostart.sh` to restart everything

**Can't install packages (permission denied):**
  - Use: `sudo dnf install ...` or `pip install --user ...`
  - UBI9 images have sudo access for the default user

## Files

```
~/devfile.yaml          # DevSpaces workspace definition
~/setup-hermes.sh       # One-time setup script
~/autostart.sh          # Auto-restart on workspace wake
~/.hermes/config.yaml   # Hermes configuration
~/.hermes/.env          # API keys and secrets
~/.hermes/logs/         # Gateway logs
```
