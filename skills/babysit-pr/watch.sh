#!/usr/bin/env bash
#
# Block until something on a pull request needs attention, print one line per
# event, and exit. Run it again after handling the events to keep watching.
#
# Usage: watch.sh <pr> [--repo <owner/repo>]
#        watch.sh <pr> [--repo <owner/repo>] --alive
#
# Events: new comments, reviews and inline review comments (except your own),
# a check failing or being cancelled, every check finishing on the current
# head, the review decision becoming APPROVED or CHANGES_REQUESTED, the PR
# being merged or closed, and the branch becoming conflicted or behind base.
#
# The last seen state is kept per PR, so events that land while the watcher is
# not running are reported as soon as it starts again. With --alive the script
# only reports whether a watcher for the PR is running (exit 0) or not (exit 1).
#
# Agent harnesses kill background commands after a while (Claude Code does it
# after 30 minutes), and an agent told a command was killed tends to give up
# on it. So a quiet watcher exits on its own after BABYSIT_MAX_MINUTES
# (default 25) and says to start it again. Nothing is lost between runs.
#
# BABYSIT_INTERVAL sets the poll interval in seconds (default 60).

set -euo pipefail

interval="${BABYSIT_INTERVAL:-60}"
max_minutes="${BABYSIT_MAX_MINUTES:-25}"

pr=""
repo_args=()
alive=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|-R) repo_args=(--repo "$2"); shift 2 ;;
    --alive) alive=1; shift ;;
    *) pr="$1"; shift ;;
  esac
done

if [[ -z "$pr" ]]; then
  echo "usage: $(basename "$0") <pr> [--repo <owner/repo>] [--alive]" >&2
  exit 1
fi

url="$(gh pr view "$pr" ${repo_args[@]+"${repo_args[@]}"} --json url --jq .url)"
slug="$(echo "$url" | sed -E 's#https://[^/]+/([^/]+)/([^/]+)/pull/([0-9]+).*#\1/\2/\3#')"
owner_repo="${slug%/*}"
number="${slug##*/}"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/babysit-pr"
key="$(echo "$slug" | tr '/' '_')"
state_file="$state_dir/$key.json"
pid_file="$state_dir/$key.pid"
mkdir -p "$state_dir"

running() {
  [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

if [[ $alive -eq 1 ]]; then
  if running; then
    echo "watcher for $url is running (pid $(cat "$pid_file"))"
    exit 0
  fi
  echo "no watcher running for $url"
  exit 1
fi

if running; then
  echo "watcher for $url is already running (pid $(cat "$pid_file"))"
  exit 2
fi

echo $$ > "$pid_file"
trap '[[ "$(cat "$pid_file" 2>/dev/null)" == "$$" ]] && rm -f "$pid_file"' EXIT

viewer="$(gh api user --jq .login)"

# Print the current PR state as one JSON object, or fail on any API error.
snapshot() {
  local pr_json inline_json checks_json

  pr_json="$(gh pr view "$number" --repo "$owner_repo" \
    --json state,reviewDecision,mergeable,mergeStateStatus,headRefOid,comments,reviews)" || return 1
  inline_json="$(gh api --paginate "repos/$owner_repo/pulls/$number/comments" \
    --jq '.[] | {id: (.id | tostring), kind: "inline comment", author: .user.login, where: "\(.path):\(.line // .original_line // "?")", text: .body}' \
    | jq -s .)" || return 1

  # gh exits non-zero while checks are pending or failing, and when there are
  # none at all, so judge success by whether it printed JSON.
  checks_json="$(gh pr checks "$number" --repo "$owner_repo" --json name,bucket,link 2>/dev/null || true)"
  [[ "$checks_json" == \[* ]] || checks_json="[]"

  jq -n --argjson pr "$pr_json" --argjson inline "$inline_json" --argjson checks "$checks_json" --arg viewer "$viewer" '
    {
      head: $pr.headRefOid,
      state: $pr.state,
      decision: ($pr.reviewDecision // ""),
      mergeable: $pr.mergeable,
      merge_state: $pr.mergeStateStatus,
      checks: $checks,
      items: (
        [$pr.comments[] | {id, kind: "comment", author: .author.login, text: .body}]
        # A COMMENTED review with no body only wraps inline comments, which are
        # reported on their own.
        + [$pr.reviews[] | select(.state != "COMMENTED" or .body != "")
            | {id, kind: "review (\(.state))", author: .author.login, text: .body}]
        + $inline
        | map(select(.author != $viewer))
      )
    }'
}

# Given the previous and current snapshots, print one line per event.
events() {
  jq -rn --argjson prev "$1" --argjson cur "$2" '
    def short: gsub("\\s+"; " ") | if length > 160 then .[:160] + "..." else . end;

    ($prev.seen // []) as $seen
    | (if $prev.head == $cur.head then $prev.checks else [] end
       | map({key: .name, value: .bucket}) | from_entries) as $before
    | ($cur.checks | map(select(.bucket == "pending")) | length) as $pending

    | ($cur.items[] | select(.id as $id | $seen | index($id) | not)
        | "new \(.kind) from \(.author)\(if .where then " on \(.where)" else "" end): \(.text | short)"),

      ($cur.checks[] | select((.bucket == "fail" or .bucket == "cancel") and $before[.name] != .bucket)
        | "check \(.bucket): \(.name) \(.link)"),

      (select(($cur.checks | length) > 0 and $pending == 0
          and (($before | length) == 0 or ($before | to_entries | any(.value == "pending"))))
        | ($cur.checks | group_by(.bucket) | map("\(length) \(.[0].bucket)") | join(", "))
        | "all checks finished on \($cur.head[:7]): \(.)"),

      (select($cur.decision != $prev.decision and ($cur.decision == "APPROVED" or $cur.decision == "CHANGES_REQUESTED"))
        | "review decision: \($cur.decision)"),

      (select($cur.state != $prev.state) | "pull request is now \($cur.state)"),

      (select($cur.mergeable == "CONFLICTING" and $prev.mergeable != "CONFLICTING")
        | "branch has merge conflicts with the base branch"),

      (select($cur.merge_state == "BEHIND" and $prev.merge_state != "BEHIND")
        | "branch is behind the base branch")
  '
}

# The snapshot to store: remember every item id seen, and keep the previous
# mergeability while GitHub is still computing it so UNKNOWN does not cause
# the same conflict to be reported twice.
next_state() {
  jq -n --argjson prev "$1" --argjson cur "$2" '
    $cur
    | .seen = ((($prev.seen // []) + [$cur.items[].id]) | unique)
    | del(.items)
    | if .mergeable == "UNKNOWN" then .mergeable = $prev.mergeable else . end
    | if .merge_state == "UNKNOWN" then .merge_state = $prev.merge_state else . end'
}

if [[ -f "$state_file" ]]; then
  prev="$(cat "$state_file")"
else
  # First run: everything already on the PR has been looked at by whoever
  # started the watcher, so only report what comes after this point.
  until cur="$(snapshot)"; do sleep "$interval"; done
  prev="$(next_state "$cur" "$cur")"
  echo "$prev" > "$state_file"
fi

if [[ "$(jq -r .state <<<"$prev")" != "OPEN" ]]; then
  echo "pull request is $(jq -r .state <<<"$prev"), nothing to watch"
  exit 0
fi

deadline=$(( $(date +%s) + max_minutes * 60 ))

while true; do
  if cur="$(snapshot)"; then
    found="$(events "$prev" "$cur")"
    prev="$(next_state "$prev" "$cur")"
    echo "$prev" > "$state_file"

    if [[ -n "$found" ]]; then
      echo "$url"
      echo "$found"
      exit 0
    fi
  fi

  if [[ $(date +%s) -ge $deadline ]]; then
    echo "$url"
    echo "no new events in ${max_minutes} minutes. This is a normal exit, not a failure: start the watcher again to keep watching"
    exit 0
  fi

  sleep "$interval"
done
