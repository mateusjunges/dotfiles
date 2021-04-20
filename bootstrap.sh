#!/bin/bash
#
# bootstrap installs things.


function bootstrapTerminal() {
    sudo -v #ask password beforehand
    source ~/.dotfiles/installscript.sh
}

function generateSSHKeyForGithub() {

}

echo 'Bootstrap terminal'
echo '------------------'

echo 'This will reset your terminal. Are you sure you want to do this? (y/N) '
read reply

if [[ $reply =~ ^[Yy]$ ]]
then
    bootstrapTerminal
fi

echo 'Do you want to generate a new ssh key for github?'

read reply_github




echo "----------------------"
echo "|      All Done!     |"
echo "----------------------"