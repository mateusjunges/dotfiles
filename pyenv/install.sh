#!/bin/sh


if test ! $(which pyenv)
then
	echo " Instlaling pyenv with brew..."

	brew install pyenv
fi

exit 0