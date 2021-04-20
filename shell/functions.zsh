#!/usr/bin/env bash

# Start an HTTP Server from a directory, optionally specifying the port
function server() {
    local port="${1:-9000}"
    sleep 2 && open "http://localhost:${port}/" &
    	# Set the default Content-Type to `text/plain` instead of `application/octet-stream`
    	# And serve everything as UTF-8 (although not technically correct, this doesn’t break anything for binary files)
    	python -c $'import SimpleHTTPServer;\nmap = SimpleHTTPServer.SimpleHTTPRequestHandler.extensions_map;\nmap[""] = "text/plain";\nfor key, value in map.items():\n\tmap[key] = value + ";charset=UTF-8";\nSimpleHTTPServer.test();' "$port"
}


function db {
    if [ "$1" = "refresh" ]; then
        mysql -uroot -e "drop database $2; create database $2"
    elif [ "$1" = "create" ]; then
        mysql -uroot -e "create database $2"
    elif [ "$1" = "drop" ]; then
        mysql -uroot -e "drop database $2"
    fi
}


function weather() {
    city="$1"

    if [ -z "$city" ]; then
        city="Ponta%20Grossa%20PR"
    fi

    eval "curl http://wttr.in/${city}"
}
