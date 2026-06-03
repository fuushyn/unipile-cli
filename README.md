# unipile-cli

A zero-dependency CLI for the [Unipile API](https://developer.unipile.com/docs/getting-started) — one API for messaging (LinkedIn, WhatsApp, Instagram, Telegram, Messenger) and email (Gmail, Outlook). Ships with a [Claude Code](https://claude.com/claude-code) skill so agents can drive it.

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/fuushyn/unipile-cli/main/install.sh | bash
```

This installs:
- the `unipile` CLI to `~/.local/bin/unipile`
- the Claude skill to `~/.claude/skills/unipile/SKILL.md`

Requires `python3` (standard library only — no pip install).

## Configure

Get an access token and your DSN from https://dashboard.unipile.com, then either export them or drop them in `~/.config/unipile/.env`:

```ini
UNIPILE_API_KEY=your_access_token
UNIPILE_DSN=https://apiXX.unipile.com:NNNNN
```

The CLI also reads a `.env` in the current directory. Auth uses the `X-API-KEY` header; the DSN is the request base URL.

## Usage

```bash
unipile accounts list                       # connected accounts (source of account_id)
unipile chats list --account <account_id>   # conversations
unipile messages list <chat_id>             # messages in a chat
unipile messages send <chat_id> "hello"     # send a DM / reply
unipile emails list --account <account_id>
unipile users <identifier> --account <account_id>

# escape hatch for any endpoint in the API reference:
unipile raw GET  /api/v1/accounts
unipile raw POST /api/v1/chats/CHAT_ID/messages --json '{"text":"hi"}'
unipile raw GET  /api/v1/chats --query account_id=ABC --query limit=50
```

Run `unipile --help` or `unipile <command> --help` for details.

## License

MIT
