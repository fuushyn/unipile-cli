---
name: unipile
description: Use the Unipile CLI to manage messaging and email accounts (LinkedIn, WhatsApp, Instagram, Telegram, Gmail/Outlook) through one API — list connected accounts, read and send chat messages, list emails, look up user profiles, and send LinkedIn invitations. Use whenever the user wants to interact with Unipile, send/read DMs or emails across providers, automate LinkedIn outreach, or hit the Unipile REST API.
---

# Unipile CLI

`unipile` is a zero-dependency CLI wrapping the [Unipile API](https://developer.unipile.com/docs/getting-started) — one API for messaging (LinkedIn, WhatsApp, Instagram, Telegram, Messenger) and email (Gmail, Outlook).

## Setup (one time)

The CLI needs two values from https://dashboard.unipile.com:
- `UNIPILE_API_KEY` — an access token (Settings → Access Tokens)
- `UNIPILE_DSN` — your data source URL, e.g. `https://api8.unipile.com:13841`

Set them as env vars or in `~/.config/unipile/.env`:

```
UNIPILE_API_KEY=xxxxx
UNIPILE_DSN=https://apiXX.unipile.com:NNNNN
```

The CLI also reads a `.env` in the current working directory. Verify with `unipile accounts list`.

## Core commands

```bash
unipile accounts list                       # connected provider accounts (get account_id here)
unipile accounts get <account_id>
unipile accounts delete <account_id>

unipile chats list --account <account_id>   # conversations
unipile chats get <chat_id>
unipile messages list <chat_id>             # messages in a conversation
unipile messages send <chat_id> "text"      # reply / send a DM

unipile emails list --account <account_id>
unipile emails get <email_id>

unipile users <identifier> --account <account_id>   # resolve a profile (e.g. a LinkedIn public id)
```

List commands accept `--cursor` and `--limit` (1–250) for pagination.

## Escape hatch — any endpoint

The convenience commands cover common routes. For anything else (LinkedIn invitations, posts, comments, sending email, search), call the API directly:

```bash
unipile raw GET /api/v1/accounts
unipile raw GET /api/v1/chats --query account_id=ABC --query limit=50
unipile raw POST /api/v1/chats/CHAT_ID/messages --json '{"text":"hi"}'
unipile raw POST /api/v1/users/invite --json '{"account_id":"ABC","identifier":"john-doe"}'
```

`--query K=V` is repeatable; `--json` takes a JSON request body. See the full endpoint list in the [API reference](https://developer.unipile.com/reference).

## Workflow tips

1. Always start with `unipile accounts list` to get the `account_id` — nearly every other call needs it.
2. To send a message: find the account → `chats list --account <id>` → `messages send <chat_id> "..."`.
3. Output is JSON; pipe to `jq` to extract fields (e.g. `unipile accounts list | jq '.items[].id'`).
4. If a call returns HTTP 503 `no_client_session`, the `UNIPILE_DSN` is wrong for that account.
