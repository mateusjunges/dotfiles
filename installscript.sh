echo 'Install oh-my-zsh'
echo '-----------------'

rm -rf $HOME/.oh-my-zsh/
curl -L https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh

# Add a global gitignore
ln -s $HOME/.dotfiles/shell/.global-gitignore $HOME/.global-gitignore
git config --global core.excludesfile $HOME/.global-gitignore

# Symlink zsh config
rm $HOME/.zshrc
ln -s $HOME/.dotfiles/shell/.zshrc $HOME/.zshrc

# Symlink vim prefs
rm $HOME/.vimrc
ln -s $HOME/.dotfiles/shell/.vimrc $HOME/.vimrc

# Symlink aliases file
rm $HOME/.zsh_aliases
ln -s $HOME/.dotfiles/shell/.zsh_aliases $HOME/.zsh_aliases

# Symlink functions
rm $HOME/.zsh_functions
ln -s $HOME/.dotfiles/shell/.zsh_functions $HOME/.zsh_functions
