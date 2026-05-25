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
