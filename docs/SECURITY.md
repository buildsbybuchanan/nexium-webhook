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
