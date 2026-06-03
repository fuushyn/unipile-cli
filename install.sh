#!/usr/bin/env bash
# Unipile CLI + agent skill installer.
#
#   curl -fsSL https://raw.githubusercontent.com/fuushyn/unipile-cli/main/install.sh | bash
#
# Pick which agents get the skill (Claude, Codex, Cursor, Gemini, Hermes):
#   ... | bash -s -- --agents claude,codex,hermes
#   ... | bash -s -- --all
#   ... | AGENTS=claude,hermes bash
# The built-in list is NOT exhaustive — point at any other agent that reads
# SKILL.md skills with a custom dir (repeatable):
#   ... | bash -s -- --dir ~/.someagent/skills --dir ./.myagent/skills
# With no selection on a terminal you get an interactive menu; piped with no
# selection it installs to whichever agents are already present on the machine.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/fuushyn/unipile-cli/main"
BIN_DIR="${UNIPILE_BIN_DIR:-$HOME/.local/bin}"
SKILL_NAME="unipile"

# Built-in agents and where each loads SKILL.md skills from. This list is NOT
# exhaustive — any other agent that reads SKILL.md skills can be targeted with
# --dir <path> (see usage above).
AGENT_KEYS="claude codex cursor gemini hermes openclaw"

agent_label() {
  case "$1" in
    claude)   echo "Claude Code" ;;
    codex)    echo "OpenAI Codex" ;;
    cursor)   echo "Cursor" ;;
    gemini)   echo "Gemini CLI" ;;
    hermes)   echo "Hermes" ;;
    openclaw) echo "OpenClaw" ;;
  esac
}
agent_home() {  # base dir used to detect that the agent is installed
  case "$1" in
    claude)   echo "$HOME/.claude" ;;
    codex)    echo "$HOME/.codex" ;;
    cursor)   echo "$HOME/.cursor" ;;
    gemini)   echo "$HOME/.gemini" ;;
    hermes)   echo "$HOME/.hermes" ;;
    openclaw) echo "$HOME/.openclaw" ;;
  esac
}
agent_skills_dir() {  # where this agent reads skills from
  case "$1" in
    claude)   echo "$HOME/.claude/skills" ;;
    codex)    echo "$HOME/.codex/skills" ;;
    cursor)   echo "$HOME/.cursor/skills" ;;
    gemini)   echo "$HOME/.gemini/skills" ;;
    hermes)   echo "$HOME/.hermes/skills" ;;
    openclaw) echo "$HOME/.openclaw/skills" ;;
  esac
}

say()  { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mnote:\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || err "python3 is required but not found."

fetch() {  # fetch <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    err "need curl or wget to download files."
  fi
}

is_known() { case " $AGENT_KEYS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
is_detected() { [ -d "$(agent_home "$1")" ]; }

# --- parse args / env ------------------------------------------------------- #
SELECTION="${AGENTS:-}"
EXTRA_DIRS="${EXTRA_DIRS:-}"
ALL=0
pending=""
for arg in "$@"; do
  if [ "$pending" = agents ]; then SELECTION="$arg"; pending=""; continue; fi
  if [ "$pending" = dir ];    then EXTRA_DIRS="$EXTRA_DIRS $arg"; pending=""; continue; fi
  case "$arg" in
    --all) ALL=1 ;;
    --agents=*) SELECTION="${arg#*=}" ;;
    --agents) pending=agents ;;
    --dir=*) EXTRA_DIRS="$EXTRA_DIRS ${arg#*=}" ;;
    --dir) pending=dir ;;
    --list)
      echo "Built-in agents (not exhaustive — use --dir <path> for others):"
      for k in $AGENT_KEYS; do printf "  %-8s %s\n" "$k" "$(agent_skills_dir "$k")"; done
      exit 0 ;;
    -h|--help)
      sed -n '2,18p' "$0" 2>/dev/null || echo "see header"; exit 0 ;;
    *) warn "ignoring unrecognized argument '$arg'" ;;
  esac
done

# --- choose targets --------------------------------------------------------- #
SELECTED=""
add_sel() { case " $SELECTED " in *" $1 "*) ;; *) SELECTED="$SELECTED $1" ;; esac; }

if [ "$ALL" = 1 ]; then
  SELECTED="$AGENT_KEYS"
elif [ -n "$SELECTION" ] || [ -n "$EXTRA_DIRS" ]; then
  # explicit selection and/or custom --dir targets: skip the interactive menu
  : "${SELECTION:=}"
  for tok in $(echo "$SELECTION" | tr ',' ' '); do
    tok="$(echo "$tok" | tr '[:upper:]' '[:lower:]')"
    [ "$tok" = "all" ] && { SELECTED="$AGENT_KEYS"; break; }
    is_known "$tok" && add_sel "$tok" || warn "unknown agent '$tok' (skipped)"
  done
elif [ -e /dev/tty ]; then
  # Interactive picker (works even under `curl | bash`, reading from the tty).
  echo "Which agents should get the '$SKILL_NAME' skill?"
  i=1
  for k in $AGENT_KEYS; do
    mark=" "; is_detected "$k" && mark="*"
    printf "  %d) [%s] %-12s %s\n" "$i" "$mark" "$(agent_label "$k")" "$(agent_skills_dir "$k")"
    i=$((i+1))
  done
  echo "  (* = detected on this machine)"
  printf "Enter numbers/names (e.g. 1,3 or claude,hermes), 'all', or Enter for detected: "
  read -r ANSWER < /dev/tty || ANSWER=""
  if [ -z "$ANSWER" ]; then
    for k in $AGENT_KEYS; do is_detected "$k" && add_sel "$k"; done
  elif [ "$(echo "$ANSWER" | tr '[:upper:]' '[:lower:]')" = "all" ]; then
    SELECTED="$AGENT_KEYS"
  else
    for tok in $(echo "$ANSWER" | tr ',' ' '); do
      tok="$(echo "$tok" | tr '[:upper:]' '[:lower:]')"
      case "$tok" in
        [1-9]*) idx=1; for k in $AGENT_KEYS; do [ "$idx" = "$tok" ] && add_sel "$k"; idx=$((idx+1)); done ;;
        *) is_known "$tok" && add_sel "$tok" || warn "unknown agent '$tok' (skipped)" ;;
      esac
    done
  fi
else
  # Non-interactive, no selection: fall back to whatever is installed.
  for k in $AGENT_KEYS; do is_detected "$k" && add_sel "$k"; done
fi

SELECTED="$(echo "$SELECTED" | xargs)"   # trim
EXTRA_DIRS="$(echo "$EXTRA_DIRS" | xargs)"
[ -z "$SELECTED" ] && [ -z "$EXTRA_DIRS" ] && warn "no agents selected — installing the CLI only."

# --- 1) CLI ----------------------------------------------------------------- #
say "Installing CLI to $BIN_DIR/unipile"
mkdir -p "$BIN_DIR"
fetch "$REPO_RAW/unipile_cli.py" "$BIN_DIR/unipile"
chmod +x "$BIN_DIR/unipile"

# --- 2) skill into each selected agent -------------------------------------- #
TMP_SKILL="$(mktemp)"
trap 'rm -f "$TMP_SKILL"' EXIT
install_skill_to() {  # install_skill_to <skills-root> <label>
  dest="$1/$SKILL_NAME"
  mkdir -p "$dest"
  cp "$TMP_SKILL" "$dest/SKILL.md"
  say "Installed skill for $2 -> $dest/SKILL.md"
}
if [ -n "$SELECTED" ] || [ -n "$EXTRA_DIRS" ]; then
  fetch "$REPO_RAW/skills/unipile/SKILL.md" "$TMP_SKILL"
  for k in $SELECTED; do
    install_skill_to "$(agent_skills_dir "$k")" "$(agent_label "$k")"
  done
  for d in $EXTRA_DIRS; do
    eval d="$d"   # expand a leading ~
    install_skill_to "$d" "custom ($d)"
  done
fi

# --- 3) report -------------------------------------------------------------- #
echo
say "Done."
echo "  CLI:    $BIN_DIR/unipile"
if [ -n "$SELECTED" ] || [ -n "$EXTRA_DIRS" ]; then
  printf "  Skill:  installed for ->"
  for k in $SELECTED; do printf ' %s' "$(agent_label "$k")"; done
  for d in $EXTRA_DIRS; do printf ' %s' "$d"; done
  echo
fi
echo

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on your PATH. Add: export PATH=\"$BIN_DIR:\$PATH\"" ; echo ;;
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
