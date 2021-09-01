# My personal dotfiles
![Readme banner](/docs/readme-image.png)

Your dotfiles are how you personalize your system. These are mine.

It contains the installation of some basic tools, some handy aliases and functions.

## Topical
Everything's built around topic areas. If you're adding a new are to your forked dotfiles, you can simply create a new directory 
and put files in there. Anything with an extension of `.zsh` will get automatically included into your shell. Anything with an 
extension of `.symlink` will get symlinked without extension into `$HOME` when you run `script/bootstrap`.

## Components
There's a few special files in the hierarchy:

- **`bin/`**: Anything in `bin` will get added to your `$PATH` and be made available everywhere.
- **`topic/*.zsh`**: Any files ending in `.zsh` get loaded into your environment.
- **`topic/path.zsh`**: Any file named `path.zsh` is loaded first and is expected o setup `$PATH` or similar.
- **`topic/completion.zsh`**: Any file named `completion.zsh` is loaded last and is expected to setup autocomplete.
- **`topic/install.sh`**: Any file named `install.sh` is executed when you run `script/install`. To avoid being loaded automatically, its 
extension is `.sh`, not `.zsh`.
- **`topic/*.symlink`**: Any file ending in `.symlink` gets symlinked into your `$HOME`. This is so you can keep all of those versioned
in your dotfiles but still keep those autoloaded files in your home directory. These get symlinked when you run `script/bootstrap`.
  
## Installation

You can install this dotfiles by cloning this repo as `.dotfiles` in your home directory and running the bootstrap script.

```bash
git clone git@github.com:mateusjunges/dotfiles.git .dotfiles
cd .dotfiles
script/bootstrap
```

This will symlink the appropriate files in `.dotfiles` to your home directory. Everything is configured and tweaked within `.dotfiles`.

The main file you'll want to change right off the bat is `zsh/zshrc.symlink`, which sets up a few paths that will be different on your particular machine.

