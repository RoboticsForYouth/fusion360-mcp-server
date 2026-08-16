#!/bin/bash
# =============================================================================
# Fusion 360 MCP — one-command installer (Absolute Zero / Robotics For Youth)
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/RoboticsForYouth/fusion360-mcp-server/main/install.sh)"
#
# Installs/updates: RFY hardened fork, Fusion add-in, uv, Claude Code MCP
# registration, Claude Desktop config, and the az-fusion-design skill.
# Idempotent: safe to re-run any time to update.
# macOS only (Windows: follow the manual guide in 03_Resources).
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/RoboticsForYouth/fusion360-mcp-server.git"
REPO_DIR="$HOME/fusion360-mcp-server"
ADDIN_DIR="$HOME/Library/Application Support/Autodesk/Autodesk Fusion 360/API/AddIns/Fusion360MCP"
SKILL_SRC="claude-skills/az-fusion-design"
SKILL_DST="$HOME/.claude/skills/az-fusion-design"
DESKTOP_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

ok()   { printf "\033[32m  ✓ %s\033[0m\n" "$1"; }
info() { printf "\033[36m→ %s\033[0m\n" "$1"; }
warn() { printf "\033[33m  ! %s\033[0m\n" "$1"; }
die()  { printf "\033[31m  ✗ %s\033[0m\n" "$1"; exit 1; }

[ "$(uname)" = "Darwin" ] || die "macOS only — Windows users: follow the manual guide."

info "1/7 Checking prerequisites"
command -v git >/dev/null || die "git not found — install Xcode Command Line Tools first: xcode-select --install"
if ! command -v uv >/dev/null && [ ! -x "$HOME/.local/bin/uv" ]; then
  info "    installing uv (Python runner)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
fi
UV_BIN="$(command -v uv || echo "$HOME/.local/bin/uv")"
[ -x "$UV_BIN" ] || die "uv install failed — install manually: brew install uv"
ok "git + uv ready ($UV_BIN)"

info "2/7 Cloning/updating the RFY hardened fork"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" pull --ff-only -q || warn "pull failed (local changes?) — continuing with existing checkout"
  ok "updated $REPO_DIR"
else
  git clone -q "$REPO_URL" "$REPO_DIR"
  ok "cloned to $REPO_DIR"
fi

info "3/7 Verifying security hardening"
if grep -rq '"execute_code"' "$REPO_DIR/src" "$REPO_DIR/addon" 2>/dev/null; then
  die "execute_code found in tool registrations — this is NOT the hardened fork. Aborting."
fi
ok "hardening confirmed (execute_code absent)"

info "4/7 Installing the Fusion 360 add-in"
mkdir -p "$(dirname "$ADDIN_DIR")"
rm -rf "$ADDIN_DIR"
cp -r "$REPO_DIR/addon" "$ADDIN_DIR"
ok "add-in installed"
pgrep -q "Autodesk Fusion" && warn "Fusion is running — RESTART Fusion so it picks up the add-in"

info "5/7 Registering with Claude Code (if installed)"
if command -v claude >/dev/null; then
  claude mcp remove fusion360 --scope user >/dev/null 2>&1 || true
  claude mcp remove fusion360 >/dev/null 2>&1 || true
  claude mcp add --scope user fusion360 -- "$UV_BIN" run --directory "$REPO_DIR" fusion360-mcp-server --mode socket >/dev/null
  ok "Claude Code: fusion360 MCP registered (user scope)"
else
  warn "Claude Code CLI not found — skipping (Desktop-only user?)"
fi

info "6/7 Configuring Claude Desktop (if installed)"
if [ -d "$HOME/Library/Application Support/Claude" ] || [ -d "/Applications/Claude.app" ]; then
  mkdir -p "$(dirname "$DESKTOP_CFG")"
  UV_BIN="$UV_BIN" REPO_DIR="$REPO_DIR" DESKTOP_CFG="$DESKTOP_CFG" python3 - <<'PYEOF'
import json, os
cfg_path = os.environ["DESKTOP_CFG"]
cfg = {}
if os.path.exists(cfg_path):
    try:
        cfg = json.load(open(cfg_path))
    except Exception:
        os.rename(cfg_path, cfg_path + ".bak")
cfg.setdefault("mcpServers", {})["fusion360"] = {
    "command": os.environ["UV_BIN"],
    "args": ["run", "--directory", os.environ["REPO_DIR"],
             "fusion360-mcp-server", "--mode", "socket"],
}
json.dump(cfg, open(cfg_path, "w"), indent=2)
PYEOF
  ok "Claude Desktop config written — fully restart Claude Desktop (Cmd+Q) to load it"
else
  warn "Claude Desktop not found — skipping"
fi

info "7/7 Installing the az-fusion-design team skill"
mkdir -p "$HOME/.claude/skills"
rm -rf "$SKILL_DST"
cp -r "$REPO_DIR/$SKILL_SRC" "$SKILL_DST"
ok "skill installed to ~/.claude/skills/az-fusion-design"

cat <<'DONE'

=============================================================
 Install complete. Final steps (the two things a script can't do):

 1. In Fusion 360:  Shift+S → Add-Ins tab → Fusion360MCP → Run
    (restart Fusion first if it was open during install)
 2. Restart Claude Desktop fully (Cmd+Q) if you use the app.

 Verify: ask Claude to "use the fusion360 ping tool"
         → expect {"pong": true}

 Rules reminder: localhost only · add-in off when not in use ·
 log AI-assisted parts in the notebook · you must be able to
 explain every part you make.
=============================================================
DONE
