#!/usr/bin/env bash

# Start a php server from a directory, optionally specifying the port
function phpserver() {
    local port="${1:-4000}"
    local ip=$(ipconfig getinfaddr en0)
    sleep 2 && open "http://${ip}:${port}/" &
    php -S "${ip}:${port}"
}

function p() {
   if [ -f vendor/bin/pest ]; then
      vendor/bin/pest "$@"
   else
      vendor/bin/phpunit "$@"
   fi
}

function pf() {
   if [ -f vendor/bin/pest ]; then
      vendor/bin/pest --filter "$@"
   else
      vendor/bin/phpunit --filter "$@"
   fi
}

function tinker()
{
  if [ -z "$1" ]
    then
       herd php artisan tinker
    else
       herd php artisan tinker --execute="dd($1);"
  fi
}

function composer-link() {
  repositoryName=${2:-local}
  branchName=${3:-"dev-master"}

  echo $branchName
  composer config repositories.$repositoryName '{"type": "path", "url": "'$1'", "options": {"symlink": true}}' --file composer.json
}
