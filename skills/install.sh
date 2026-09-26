#!/usr/bin/env bash
#
# Symlinks each skill into the Claude Code and Codex skills directories. Skills
# installed by other tools (ui.sh, the Claude app sync) live only in those
# directories, which keeps them out of this repo.

set -e

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for target in ~/.claude/skills ~/.agents/skills; do
    # Older installs linked the whole directory into the repo.
    [ -L "$target" ] && rm "$target"
    mkdir -p "$target"

    # Prune links left behind by skills that were removed or moved.
    for link in "$target"/*; do
        [ -L "$link" ] && [ ! -e "$link" ] && rm "$link"
    done

    for skill in "$SKILLS_DIR"/*/; do
        ln -sfn "${skill%/}" "$target/$(basename "$skill")"
    done
done

echo "Skills linked into ~/.claude/skills and ~/.agents/skills"
