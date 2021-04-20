#!/bin/sh
#
# Usage: ytdl <youtube link>
# Description: Download a video from youtube
#
function ytdl() {
  $DOTFILES/bin/yt $1
}