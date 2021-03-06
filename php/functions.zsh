#!/usr/bin/env bash

# Switch php version
function switchPHP() {
    sudo update-alternatives --config php
}

# Start a php server from a directory, optionally specifying the port
function phpserver() {
    local port="${1:-4000}"
    local ip=$(ipconfig getinfaddr en0)
    sleep 2 && open "http://${ip}:${port}/" &
    php -S "${ip}:${port}"
}

function ray() {
    cd ~/apps
    THIS_DIR=$(realpath `dirname $0`)
    LATEST_BINARY=$(ls -1 $THIS_DIR/Ray-*.*.AppImage | sort -r | head -n 1)

    $LATEST_BINARY
}

function tinkerwell() {
  cd ~/apps
  THIS_DIR=$(realpath `dirname $0`)
  LATEST_BINARY=$(ls -1 $THIS_DIR/Tinkerwell-*.*.*.AppImage | sort -r | head -n 1)

  $LATEST_BINARY
}