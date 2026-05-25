#!/usr/bin/env bash
set -euo pipefail

FOUND=0

scan() {
  LABEL="$1"
  PATTERN="$2"

  MATCHES="$(grep -RInE \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=.github \
    --exclude=".env.example" \
    --exclude="setup_nexium_webhook.sh" \
    --exclude="local-secret-scan.sh" \
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
