# Commit
function commit() {
    message="$1"

    if [ "$message" = "" ]; then
        message="wip"
    fi

    eval "git commit -S -m '${message}'"
}

function commitd() {
    message="$1"
    
    branch=$(get_current_branch)
    
    description=${branch%_*}
    
    eval "git commit -S -m '${message}' -m '${description}'"
}

function commit() {
    message="$1"
    
    description="$2"

    if [ "$message" = "" ]; then
        message="wip"
    fi
    
    eval "git commit -S -m '${message}' -m '${description}'"
}

# Git checkout
function gco() {
    branch=$1

    if [ "$branch" = "" ]; then
        branch="master"
    fi

    eval "git checkout $branch"
}

# Returns the current git branch
function get_current_branch() {
    git branch --show-current
}

# Push
function push() {
    branch="$1"

    if [ "$branch" = "" ]; then
        branch=$(get_current_branch)
    fi

    eval "git push origin ${branch}"
}

# Pull
function pull() {
    branch="$1"

    if [ "$branch" = "" ]; then
        branch=$(get_current_branch)
    fi

    eval "git pull origin ${branch}"
}
