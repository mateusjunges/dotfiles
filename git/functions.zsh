# Commit
function commit() {
    message="$1"

    if [ "$message" = "" ]; then
        message="wip"
    fi

    eval "git commit -S -m '${message}'"
}

function commit() {
    commitMessage="$*"

      if [ "$commitMessage" = "" ]; then
         # Start spinner in background (suppress job control messages)
         {
           spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
           while true; do
             for (( i=0; i<${#spinner}; i++ )); do
               printf "\r${spinner:$i:1} Generating commit message..."
               sleep 0.1
             done
           done
         } &!
         spinner_pid=$!

         # Cleanup function for interrupt
         cleanup() {
           { kill $spinner_pid; wait $spinner_pid; } 2>/dev/null
           printf "\r\033[K"
           trap - INT
           return 1
         }
         trap cleanup INT

         # Get diff with size limit, include stat summary for context
         diff_input=$(echo "=== Summary ===" && git diff --cached --stat && echo -e "\n=== Diff (truncated if large) ===" && git diff --cached | head -c 50000)
         commitMessage=$(echo "$diff_input" | claude -p "Write a single-line commit message for this diff. It MUST be under 72 characters. Be concise. Output ONLY the message, no quotes, no explanation, no markdown.")

         # Stop spinner and clear line
         trap - INT
         { kill $spinner_pid; wait $spinner_pid; } 2>/dev/null
         printf "\r\033[K"

         git commit -m "$commitMessage"
         return
      fi

      eval "git commit -a -m '${commitMessage}'"
}

function wip() {
  eval "git add ."

  commit

  eval "push"
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
