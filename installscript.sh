#!/usr/bin/env bash

echo 'Install oh-my-zsh'
echo '-----------------'

rm -rf $HOME/.oh-my-zsh/
curl -L https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh

echo 'Installing ZSH Autosuggestions...'
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

echo 'Installing ZSH syntax highlighting...'
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Add a global gitignore
echo 'Adding a global gitignore file...'
ln -s $HOME/.dotfiles/shell/.global-gitignore $HOME/.global-gitignore
git config --global core.excludesfile $HOME/.global-gitignore
echo '-----------------'

# Symlink zsh config
echo 'Symlinking zsh config...'
rm $HOME/.zshrc
ln -s $HOME/.dotfiles/shell/.zshrc $HOME/.zshrc
echo '-----------------'

# Symlink vim prefs
echo 'Symlinking vim prefs...'
rm $HOME/.vimrc
ln -s $HOME/.dotfiles/shell/.vimrc $HOME/.vimrc
echo '-----------------'

# Symlink aliases file
echo 'Symlinking aliases...'
rm $HOME/.zsh_aliases
ln -s $HOME/.dotfiles/shell/.zsh_aliases $HOME/.zsh_aliases
echo '-----------------'

# Symlink functions
echo 'Symlinking zsh functions...'
rm $HOME/.zsh_functions
ln -s $HOME/.dotfiles/shell/.zsh_functions $HOME/.zsh_functions
echo '-----------------'

# Configure git
echo 'Configuring git...'
git config --global user.name "Mateus Junges"
git config --global user.email "mateus@junges.dev"
echo '-----------------'
echo "sign commits: https://help.github.com/en/github/authenticating-to-github/associating-an-email-with-your-gpg-key"

source ~/.zshrc

echo 'Installation finished successfully!'
