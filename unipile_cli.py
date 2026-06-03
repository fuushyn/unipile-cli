#!/usr/bin/env python3
"""Unipile CLI — a zero-dependency client for the Unipile API.

Docs: https://developer.unipile.com/docs/getting-started

Configuration (env vars, or a .env in the cwd / ~/.config/unipile/.env):
  UNIPILE_API_KEY   Access token from https://dashboard.unipile.com/access-tokens
  UNIPILE_DSN       Your DSN, e.g. https://api8.unipile.com:13841 (from the dashboard)

Auth: every request sends the `X-API-KEY` header. The base URL is your DSN.

Examples:
  unipile accounts list
  unipile accounts get <account_id>
  unipile chats list --account <account_id>
  unipile messages list <chat_id>
  unipile messages send <chat_id> "hello there"
  unipile emails list --account <account_id>
  unipile users get john-doe --account <account_id>
  unipile raw GET /api/v1/accounts
  unipile raw POST /api/v1/chats/CHAT_ID/messages --json '{"text":"hi"}'
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API_PREFIX = "/api/v1"


# --------------------------------------------------------------------------- #
# Config
# --------------------------------------------------------------------------- #
def _load_dotenv() -> None:
    """Load config from candidate .env files (real env vars always win)."""
    candidates = [
        Path.cwd() / ".env",
        Path.home() / ".config" / "unipile" / ".env",
        Path.home() / ".unipile.env",
    ]
    # Back-compat: walk up from the script dir (e.g. agents/.env).
    here = Path(__file__).resolve()
    candidates += [parent / ".env" for parent in [here.parent, *here.parents]]
    for env_path in candidates:
        if env_path.is_file():
            _parse_dotenv(env_path)


def _parse_dotenv(path: Path) -> None:
    try:
        for raw in path.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value
    except OSError:
        pass


def _config() -> tuple[str, str]:
    api_key = os.environ.get("UNIPILE_API_KEY", "").strip()
    dsn = os.environ.get("UNIPILE_DSN", "").strip().rstrip("/")
    if not api_key:
        _die(
            "UNIPILE_API_KEY is not set. Export it, or add it to ./.env or "
            "~/.config/unipile/.env (see https://dashboard.unipile.com/access-tokens)."
        )
    if not dsn:
        _die(
            "UNIPILE_DSN is not set. Find your DSN at https://dashboard.unipile.com "
            "(e.g. https://api8.unipile.com:13841) and set UNIPILE_DSN in your env "
            "or ~/.config/unipile/.env."
        )
    if not dsn.startswith("http"):
        dsn = "https://" + dsn
    return api_key, dsn


# --------------------------------------------------------------------------- #
# HTTP
# --------------------------------------------------------------------------- #
def request(
    method: str,
    path: str,
    *,
    query: dict | None = None,
    body: dict | None = None,
):
    api_key, dsn = _config()
    if not path.startswith("/"):
        path = "/" + path
    url = dsn + path
    if query:
        clean = {k: v for k, v in query.items() if v is not None}
        if clean:
            url += "?" + urllib.parse.urlencode(clean)

    data = None
    headers = {"X-API-KEY": api_key, "accept": "application/json"}
    if body is not None:
        data = json.dumps(body).encode()
        headers["content-type"] = "application/json"

    req = urllib.request.Request(url, data=data, method=method.upper(), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload = resp.read().decode()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        _die(f"HTTP {exc.code} {exc.reason} for {method.upper()} {path}\n{detail}", code=1)
    except urllib.error.URLError as exc:
        _die(f"Request failed for {method.upper()} {url}: {exc.reason}", code=1)

    if not payload:
        return None
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        return payload


def _print(result) -> None:
    if result is None:
        print("(no content)")
    elif isinstance(result, str):
        print(result)
    else:
        print(json.dumps(result, indent=2, ensure_ascii=False))


def _die(msg: str, code: int = 2) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


# --------------------------------------------------------------------------- #
# Commands
# --------------------------------------------------------------------------- #
def cmd_accounts(args):
    if args.action == "list":
        _print(request("GET", f"{API_PREFIX}/accounts",
                        query={"cursor": args.cursor, "limit": args.limit}))
    elif args.action == "get":
        _print(request("GET", f"{API_PREFIX}/accounts/{args.id}"))
    elif args.action == "delete":
        _print(request("DELETE", f"{API_PREFIX}/accounts/{args.id}"))


def cmd_chats(args):
    if args.action == "list":
        _print(request("GET", f"{API_PREFIX}/chats",
                        query={"account_id": args.account, "cursor": args.cursor,
                               "limit": args.limit}))
    elif args.action == "get":
        _print(request("GET", f"{API_PREFIX}/chats/{args.id}"))


def cmd_messages(args):
    if args.action == "list":
        _print(request("GET", f"{API_PREFIX}/chats/{args.chat_id}/messages",
                        query={"cursor": args.cursor, "limit": args.limit}))
    elif args.action == "send":
        _print(request("POST", f"{API_PREFIX}/chats/{args.chat_id}/messages",
                        body={"text": args.text}))


def cmd_emails(args):
    if args.action == "list":
        _print(request("GET", f"{API_PREFIX}/emails",
                        query={"account_id": args.account, "cursor": args.cursor,
                               "limit": args.limit}))
    elif args.action == "get":
        _print(request("GET", f"{API_PREFIX}/emails/{args.id}"))


def cmd_users(args):
    _print(request("GET", f"{API_PREFIX}/users/{urllib.parse.quote(args.identifier, safe='')}",
                   query={"account_id": args.account}))


def cmd_raw(args):
    body = None
    if args.json is not None:
        try:
            body = json.loads(args.json)
        except json.JSONDecodeError as exc:
            _die(f"--json is not valid JSON: {exc}")
    query = dict(p.split("=", 1) for p in args.query) if args.query else None
    _print(request(args.method, args.path, query=query, body=body))


# --------------------------------------------------------------------------- #
# Parser
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="unipile",
        description="Zero-dependency Unipile API CLI (https://developer.unipile.com).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Config via env or ~/.config/unipile/.env: UNIPILE_API_KEY, UNIPILE_DSN.",
    )
    sub = p.add_subparsers(dest="command", required=True)

    def add_paging(sp):
        sp.add_argument("--cursor", help="pagination cursor")
        sp.add_argument("--limit", type=int, help="items per page (1-250)")

    # accounts
    acc = sub.add_parser("accounts", help="manage connected accounts")
    acc_s = acc.add_subparsers(dest="action", required=True)
    acc_list = acc_s.add_parser("list", help="list connected accounts")
    add_paging(acc_list)
    acc_get = acc_s.add_parser("get", help="get one account")
    acc_get.add_argument("id")
    acc_del = acc_s.add_parser("delete", help="disconnect/delete an account")
    acc_del.add_argument("id")
    acc.set_defaults(func=cmd_accounts)

    # chats
    ch = sub.add_parser("chats", help="list/get chats")
    ch_s = ch.add_subparsers(dest="action", required=True)
    ch_list = ch_s.add_parser("list", help="list chats")
    ch_list.add_argument("--account", help="filter by account_id")
    add_paging(ch_list)
    ch_get = ch_s.add_parser("get", help="get one chat")
    ch_get.add_argument("id")
    ch.set_defaults(func=cmd_chats)

    # messages
    msg = sub.add_parser("messages", help="list/send chat messages")
    msg_s = msg.add_subparsers(dest="action", required=True)
    msg_list = msg_s.add_parser("list", help="list messages in a chat")
    msg_list.add_argument("chat_id")
    add_paging(msg_list)
    msg_send = msg_s.add_parser("send", help="send a message in a chat")
    msg_send.add_argument("chat_id")
    msg_send.add_argument("text")
    msg.set_defaults(func=cmd_messages)

    # emails
    em = sub.add_parser("emails", help="list/get emails")
    em_s = em.add_subparsers(dest="action", required=True)
    em_list = em_s.add_parser("list", help="list emails")
    em_list.add_argument("--account", help="filter by account_id")
    add_paging(em_list)
    em_get = em_s.add_parser("get", help="get one email")
    em_get.add_argument("id")
    em.set_defaults(func=cmd_emails)

    # users
    us = sub.add_parser("users", help="retrieve a user/profile")
    us.add_argument("identifier", help="provider identifier or public id")
    us.add_argument("--account", required=True, help="account_id to query through")
    us.set_defaults(func=cmd_users)

    # raw escape hatch
    raw = sub.add_parser("raw", help="call any endpoint directly")
    raw.add_argument("method", help="HTTP method, e.g. GET POST DELETE")
    raw.add_argument("path", help="path, e.g. /api/v1/accounts")
    raw.add_argument("--json", help="JSON request body")
    raw.add_argument("--query", action="append", metavar="K=V",
                     help="query param (repeatable)")
    raw.set_defaults(func=cmd_raw)

    return p


def main(argv=None) -> int:
    _load_dotenv()
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
