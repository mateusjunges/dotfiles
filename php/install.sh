#!/bin/sh
#
# PIE (PHP Installer for Extensions)
#
# This installs PIE as a standalone phar in ~/.local/bin so it runs with
# whatever php binary is first on the PATH (Herd), instead of being tied
# to the Homebrew php formula.

if test ! $(which pie)
then
  echo "  Installing PIE for you."

  mkdir -p "$HOME/.local/bin"
  curl -fsSL -o "$HOME/.local/bin/pie" https://github.com/php/pie/releases/latest/download/pie.phar
  chmod +x "$HOME/.local/bin/pie"
fi

exit 0
