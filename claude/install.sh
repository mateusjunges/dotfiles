#!/usr/bin/env bash
#
# Claude Code installation script
# Can be run independently or as part of full dotfiles setup

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo ""; echo -e "${BLUE}➜${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo "Claude Code Installation"
echo "========================"
echo ""

# Install Claude Code
step "Installing Claude Code CLI"
if command -v claude &>/dev/null; then
    warn "Claude Code already installed"
else
    # Try Homebrew first (modern)
    if command -v brew &>/dev/null; then
        brew install --cask claude-code || warn "Claude Code installation failed"
    else
        # Fallback to curl installer
        warn "Homebrew not found, using curl installer"
        curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code installation failed"
    fi
fi
success "Claude Code processed"

# Check if running from dotfiles repo
DOTFILES_DIR="$HOME/.dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    # Try to detect if script is in a dotfiles directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/../claude/CLAUDE.md" ]; then
        DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
fi

# Claude configuration
if [ -d "$DOTFILES_DIR/claude" ]; then
    step "Setting up Claude Code configuration"
    mkdir -p ~/.claude

    # Symlink configuration files
    ln -sf "$DOTFILES_DIR/claude/CLAUDE.md" ~/.claude/CLAUDE.md
    ln -sf "$DOTFILES_DIR/claude/laravel-php-guidelines.md" ~/.claude/laravel-php-guidelines.md
    ln -sf "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json
    ln -sf "$DOTFILES_DIR/claude/statusline.sh" ~/.claude/statusline.sh

    # Symlink each skill into a real skills directory, so skills installed by
    # other tools (ui.sh, the Claude app sync) stay out of the repo. Links left
    # behind by skills removed from the repo are pruned.
    [ -L ~/.claude/skills ] && rm ~/.claude/skills
    mkdir -p ~/.claude/skills
    for link in ~/.claude/skills/*; do
        [ -L "$link" ] && [ ! -e "$link" ] && rm "$link"
    done
    for skill in "$DOTFILES_DIR"/claude/skills/*/; do
        ln -sfn "${skill%/}" ~/.claude/skills/"$(basename "$skill")"
    done

    # Symlink entire agents directory
    rm -rf ~/.claude/agents
    ln -sf "$DOTFILES_DIR/claude/agents" ~/.claude/agents

    # Worktree sites: T3 provisions each new worktree through its setup script,
    # registered below as a default for every project, and a launchd sweeper
    # reaps them for every T3 agent runtime. The hooks in settings.json call the
    # script by its dotfiles path.
    /usr/bin/python3 - "$HOME/.t3/userdata/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
settings = json.load(open(path)) if os.path.exists(path) else {}
scripts = [s for s in settings.get("defaultProjectScripts", []) if s.get("id") != "setup-worktree"]
scripts.append({
    "id": "setup-worktree",
    "name": "Setup worktree",
    "command": '"$HOME/.dotfiles/t3/worktree-site.sh" --setup',
    "icon": "configure",
    "runOnWorktreeCreate": True,
    "async": True,
})
settings["defaultProjectScripts"] = scripts
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(settings, open(path, "w"), indent=2)
PY
    mkdir -p ~/Library/LaunchAgents
    ln -sf "$DOTFILES_DIR/t3/dev.junges.worktree-sites.plist" ~/Library/LaunchAgents/dev.junges.worktree-sites.plist
    launchctl bootout "gui/$(id -u)/dev.junges.worktree-sites" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/dev.junges.worktree-sites.plist 2>/dev/null || true
    ln -sf "$DOTFILES_DIR/t3/worktree-site.sh" "$DOTFILES_DIR/bin/worktree-site"

    success "Claude Code configured"
else
    warn "Dotfiles directory not found, skipping configuration"
    echo "  To set up configuration later, clone dotfiles to ~/.dotfiles"
fi
