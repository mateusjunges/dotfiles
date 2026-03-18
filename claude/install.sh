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

    # Symlink entire skills directory
    rm -rf ~/.claude/skills
    ln -sf "$DOTFILES_DIR/claude/skills" ~/.claude/skills

    # Symlink entire agents directory
    rm -rf ~/.claude/agents
    ln -sf "$DOTFILES_DIR/claude/agents" ~/.claude/agents

    success "Claude Code configured"
else
    warn "Dotfiles directory not found, skipping configuration"
    echo "  To set up configuration later, clone dotfiles to ~/.dotfiles"
fi
