#!/usr/bin/env bash
# Unipile CLI + Claude skill installer.
#   curl -fsSL https://raw.githubusercontent.com/fuushyn/unipile-cli/main/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/fuushyn/unipile-cli/main"
BIN_DIR="${UNIPILE_BIN_DIR:-$HOME/.local/bin}"
SKILL_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/unipile"

say() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
err() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || err "python3 is required but not found."

fetch() {
  # fetch <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    err "need curl or wget to download files."
  fi
}

# 1) CLI -> ~/.local/bin/unipile
say "Installing CLI to $BIN_DIR/unipile"
mkdir -p "$BIN_DIR"
fetch "$REPO_RAW/unipile_cli.py" "$BIN_DIR/unipile"
chmod +x "$BIN_DIR/unipile"

# 2) Skill -> ~/.claude/skills/unipile/SKILL.md
say "Installing Claude skill to $SKILL_DIR"
mkdir -p "$SKILL_DIR"
fetch "$REPO_RAW/skills/unipile/SKILL.md" "$SKILL_DIR/SKILL.md"

# 3) Report
say "Installed."
echo
echo "  CLI:   $BIN_DIR/unipile"
echo "  Skill: $SKILL_DIR/SKILL.md"
echo

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf '\033[1;33mnote:\033[0m %s is not on your PATH. Add:\n  export PATH="%s:$PATH"\n\n' "$BIN_DIR" "$BIN_DIR" ;;
esac

cat <<'EOF'
Next: add your credentials (from https://dashboard.unipile.com):

  mkdir -p ~/.config/unipile
  cat > ~/.config/unipile/.env <<'ENV'
  UNIPILE_API_KEY=your_access_token
  UNIPILE_DSN=https://apiXX.unipile.com:NNNNN
  ENV

Then verify:

  unipile accounts list
EOF
