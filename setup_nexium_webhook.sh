#!/usr/bin/env bash
set -euo pipefail

REPO_FULL_NAME="buildsbybuchanan/nexium-webhook"
REPO_URL="https://github.com/buildsbybuchanan/nexium-webhook.git"

echo "============================================================"
echo "NEXIUM WEBHOOK PUBLIC REPO SETUP"
echo "============================================================"
echo "Repo:   $REPO_FULL_NAME"
echo "URL:    $REPO_URL"
echo "Folder: $(pwd)"
echo "============================================================"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed."
  echo "Run: sudo apt update && sudo apt install git -y"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI is not installed in WSL."
  echo "Install it first, then rerun this script."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI is not logged in."
  echo "Run these first:"
  echo "  gh auth login"
  echo "  gh auth setup-git"
  exit 1
fi

echo ""
echo "[1/8] Initialising Git repo..."

git init
git branch -M main

if git remote | grep -q '^origin$'; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

echo ""
echo "[2/8] Creating folders..."

mkdir -p .github/workflows docs scripts

echo ""
echo "[3/8] Writing .gitignore..."

cat > .gitignore <<'EOF_GITIGNORE'
# Environment / secrets
.env
.env.*
!.env.example
*.pem
*.key
*.crt
*.p12
*.pfx
*.jks
id_rsa
id_ed25519
secrets.json
credentials
credentials.json
token.json
service-account*.json
firebase-adminsdk*.json

# Dependencies
node_modules/

# Build / hosting
dist/
build/
coverage/
.vercel/
.netlify/
.railway/

# Archives
*.zip
*.tar
*.tar.gz
*.gz
*.rar
*.7z

# Logs
logs/
*.log

# OS / editor
.DS_Store
Thumbs.db
.vscode/
.idea/
EOF_GITIGNORE

echo ""
echo "[4/8] Writing README and docs..."

cat > README.md <<'EOF_README'
# Nexium Webhook

![Repository Event Notifications](https://github.com/buildsbybuchanan/nexium-webhook/actions/workflows/repo-events.yml/badge.svg)
![Secret Safety Scan](https://github.com/buildsbybuchanan/nexium-webhook/actions/workflows/security-scan.yml/badge.svg)
![Webhook Health Check](https://github.com/buildsbybuchanan/nexium-webhook/actions/workflows/webhook-health.yml/badge.svg)

Nexium Webhook is a public automation showcase by BuildsByBuchanan.

It demonstrates GitHub Actions, Discord webhook notifications, repository event monitoring, secret scanning, and safe secret handling.

## Security

This repository is public.

Do not commit real webhook URLs, `.env` files, API keys, database passwords, JWT secrets, PEM files, private keys, or cloud credentials.

Use GitHub Actions Secrets for:

```text
DISCORD_WEBHOOK_URL
```

## Workflows

| Workflow | Purpose |
|---|---|
| Repository Event Notifications | Sends selected GitHub events to Discord |
| Secret Safety Scan | Blocks obvious leaked secrets |
| Webhook Health Check | Manually tests the Discord webhook |
EOF_README

cat > .env.example <<'EOF_ENV'
# Example only.
# Store the real value in GitHub Actions Secrets.

DISCORD_WEBHOOK_URL=store_this_in_github_actions_secrets
EOF_ENV

cat > docs/SECURITY.md <<'EOF_SECURITY'
# Security

This is a public repository.

Never commit:

- Discord webhook URLs
- API keys
- JWT secrets
- Database URLs with passwords
- PEM/private key files
- `.env` files
- Cloud credentials

Required GitHub Actions secret:

```text
DISCORD_WEBHOOK_URL
```

If a webhook is ever pasted into a terminal, screenshot, commit, or chat, regenerate it immediately.
EOF_SECURITY

echo ""
echo "[5/8] Writing GitHub Actions workflows..."

cat > .github/workflows/repo-events.yml <<'EOF_REPO_EVENTS'
name: Repository Event Notifications

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  issues:
    types: [opened, closed, reopened]
  release:
    types: [published]
  workflow_dispatch:

jobs:
  notify:
    runs-on: ubuntu-latest

    steps:
      - name: Send repository event to Discord
        env:
          DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
          EVENT_NAME: ${{ github.event_name }}
          REPOSITORY: ${{ github.repository }}
          ACTOR: ${{ github.actor }}
          REF_NAME: ${{ github.ref_name }}
          COMMIT_SHA: ${{ github.sha }}
          RUN_URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
        run: |
          if [ -z "$DISCORD_WEBHOOK_URL" ]; then
            echo "No Discord webhook configured. Skipping notification."
            exit 0
          fi

          SHORT_SHA="${COMMIT_SHA:0:7}"

          PAYLOAD=$(cat <<JSON
          {
            "username": "Nexium Webhook",
            "content": "Repository event detected.",
            "embeds": [
              {
                "title": "${EVENT_NAME} on ${REPOSITORY}",
                "description": "Actor: ${ACTOR}\\nBranch: ${REF_NAME}\\nCommit: ${SHORT_SHA}",
                "url": "${RUN_URL}",
                "color": 3447003
              }
            ]
          }
JSON
          )

          curl -sS \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$PAYLOAD" \
            "$DISCORD_WEBHOOK_URL"
EOF_REPO_EVENTS

cat > .github/workflows/security-scan.yml <<'EOF_SECURITY_SCAN'
name: Secret Safety Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  secret-scan:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Scan for unsafe secret patterns
        run: |
          FOUND=0

          scan() {
            LABEL="$1"
            PATTERN="$2"

            MATCHES="$(grep -RInE \
              --exclude-dir=.git \
              --exclude-dir=node_modules \
              --exclude=".env.example" \
              --binary-files=without-match \
              -- "$PATTERN" . || true)"

            if [ -n "$MATCHES" ]; then
              FOUND=1
              echo ""
              echo "---- $LABEL ----"
              echo "$MATCHES"
            fi
          }

          scan "Discord webhook URL" 'https://discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9._-]+'
          scan "AWS access key" 'AKIA[0-9A-Z]{16}'
          scan "Private key block" '-----BEGIN .*PRIVATE KEY-----'
          scan "GitHub token" 'gh[pousr]_[A-Za-z0-9_]{30,}'
          scan "Google API key" 'AIza[0-9A-Za-z_-]{35}'
          scan "Database URL with password" '(postgres|postgresql|mysql|mongodb)(\+srv)?://[^$[:space:]'"'"'"]+:[^$[:space:]'"'"'"]+@'

          if [ "$FOUND" = "1" ]; then
            echo ""
            echo "Security scan failed."
            exit 1
          fi

          echo "No obvious secrets found."
EOF_SECURITY_SCAN

cat > .github/workflows/webhook-health.yml <<'EOF_WEBHOOK_HEALTH'
name: Webhook Health Check

on:
  workflow_dispatch:

jobs:
  webhook-health:
    runs-on: ubuntu-latest

    steps:
      - name: Test Discord webhook
        env:
          DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
          REPOSITORY: ${{ github.repository }}
          ACTOR: ${{ github.actor }}
          RUN_URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
        run: |
          if [ -z "$DISCORD_WEBHOOK_URL" ]; then
            echo "DISCORD_WEBHOOK_URL is not configured."
            exit 1
          fi

          PAYLOAD=$(cat <<JSON
          {
            "username": "Nexium Webhook",
            "content": "Webhook health check passed.",
            "embeds": [
              {
                "title": "Nexium Webhook Health Check",
                "description": "Triggered by: ${ACTOR}\\nRepository: ${REPOSITORY}",
                "url": "${RUN_URL}",
                "color": 3066993
              }
            ]
          }
JSON
          )

          curl -sS \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$PAYLOAD" \
            "$DISCORD_WEBHOOK_URL"
EOF_WEBHOOK_HEALTH

echo ""
echo "[6/8] Writing local secret scan..."

cat > scripts/local-secret-scan.sh <<'EOF_LOCAL_SCAN'
#!/usr/bin/env bash
set -euo pipefail

FOUND=0

scan() {
  LABEL="$1"
  PATTERN="$2"

  MATCHES="$(grep -RInE \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude=".env.example" \
    --binary-files=without-match \
    -- "$PATTERN" . || true)"

  if [ -n "$MATCHES" ]; then
    FOUND=1
    echo ""
    echo "---- $LABEL ----"
    echo "$MATCHES"
  fi
}

scan "Discord webhook URL" 'https://discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9._-]+'
scan "AWS access key" 'AKIA[0-9A-Z]{16}'
scan "Private key block" '-----BEGIN .*PRIVATE KEY-----'
scan "GitHub token" 'gh[pousr]_[A-Za-z0-9_]{30,}'
scan "Google API key" 'AIza[0-9A-Za-z_-]{35}'

if [ "$FOUND" = "1" ]; then
  echo ""
  echo "Local secret scan failed."
  exit 1
fi

echo "Local secret scan passed."
EOF_LOCAL_SCAN

chmod +x scripts/local-secret-scan.sh
./scripts/local-secret-scan.sh

echo ""
echo "[7/8] Optional GitHub secret setup..."

echo "Do you want to add DISCORD_WEBHOOK_URL to GitHub Actions Secrets now?"
echo "Type YES to add it, or press Enter to skip:"
read -r ADD_SECRET

if [ "$ADD_SECRET" = "YES" ]; then
  echo ""
  echo "Paste the NEW Discord webhook URL."
  echo "It will not be saved into any file."
  read -r -s WEBHOOK_URL
  echo ""

  if printf "%s" "$WEBHOOK_URL" | grep -Eq '^https://discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9._-]+$'; then
    printf "%s" "$WEBHOOK_URL" | gh secret set DISCORD_WEBHOOK_URL --repo "$REPO_FULL_NAME"
    echo "GitHub Actions secret saved."
  else
    echo "ERROR: Invalid Discord webhook URL."
    exit 1
  fi
else
  echo "Skipped GitHub secret setup."
fi

echo ""
echo "[8/8] Commit and push..."

git add .

echo ""
echo "Files staged:"
git status --short

echo ""
echo "Type PUSH to commit and push to GitHub:"
read -r CONFIRM

if [ "$CONFIRM" != "PUSH" ]; then
  echo "Cancelled. Nothing pushed."
  exit 0
fi

git commit -m "Initial Nexium webhook automation setup" || echo "Nothing new to commit."
git push -u origin main

echo ""
echo "============================================================"
echo "DONE"
echo "Nexium Webhook repo is live."
echo "============================================================"
echo "Open:"
echo "https://github.com/buildsbybuchanan/nexium-webhook"
echo ""
echo "Then test:"
echo "Actions -> Webhook Health Check -> Run workflow"
