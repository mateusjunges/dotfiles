#!/usr/bin/env bash
#
# Give every t3 worktree its own Herd site and database, so a branch can be
# opened in a browser without checking it out in the default clone.
#
#   worktree-site.sh              provision $PWD (idempotent)
#   worktree-site.sh --hook       read the hook payload on stdin, detach, provision
#   worktree-site.sh --hook-remove tear down the worktree named on stdin
#   worktree-site.sh --status     print the site for $PWD
#   worktree-site.sh --prune      unlink sites whose worktree is gone
#   worktree-site.sh --remove     unlink the site for $PWD
#   worktree-site.sh --reap       tear down worktrees whose T3 thread is settled
#   worktree-site.sh --reap -n    print what --reap would tear down, changing nothing
#
# A worktree's database starts from storage/database/copy.dump when the project
# keeps one, and from a fresh migration with seeders when it does not.
#
set -uo pipefail

WORKTREE_ROOT="$HOME/.t3/worktrees"
STATE_DIR="$HOME/.claude/worktree-sites"
LOG="$STATE_DIR/provision.log"
HERD="$HOME/Library/Application Support/Herd/bin/herd"
MYSQL="$HOME/Library/Application Support/Herd/bin/mysql"
T3_STATE="${T3_STATE:-$HOME/.t3/userdata/state.sqlite}"
DUMP_RELATIVE="storage/database/copy.dump"

mkdir -p "$STATE_DIR"

# The sweep runs on every session start, so the log is capped rather than left
# to grow without bound.
log() {
    [[ -f "$LOG" && "$(wc -c <"$LOG")" -gt 1048576 ]] && { tail -n 500 "$LOG" >"$LOG.trim" && mv "$LOG.trim" "$LOG"; }
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"
}
slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//'; }
digest() { printf '%s' "$1" | shasum | cut -c1-12; }
state_file() { printf '%s/%s.env' "$STATE_DIR" "$(digest "$1")"; }

notify() { osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1 || true; }

# Every entry Herd has linked, as "name<TAB>path".
herd_links() {
    "$HERD" links 2>/dev/null | awk -F'|' '
        NF > 5 && $2 !~ /Site/ {
            gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $5)
            if ($2 != "" && $5 != "") print $2 "\t" $5
        }'
}

# A worktree qualifies only if it is a Laravel app under the t3 worktree root.
# Anything else is silently skipped, so non-Laravel repos cost nothing.
qualifies() {
    local dir="$1"
    [[ "$dir" == "$WORKTREE_ROOT"/* ]] || return 1
    [[ -f "$dir/artisan" && -f "$dir/composer.json" ]] || return 1
    [[ -x "$HERD" ]] || return 1
    return 0
}

main_clone() {
    local common
    common="$(git -C "$1" rev-parse --git-common-dir 2>/dev/null)" || return 1
    dirname "$common"
}

# storage/ is not something a branch carries around, so the dump realistically
# lives in the main clone; the worktree is checked first only for the project
# that does commit one.
find_dump() {
    local dir="$1" main="$2" candidate
    for candidate in "$dir/$DUMP_RELATIVE" "$main/$DUMP_RELATIVE"; do
        [[ -s "$candidate" ]] && { printf '%s' "$candidate"; return 0; }
    done
    return 1
}

# Fill a database that was just created: from the project's dump when there is
# one, otherwise from a fresh migration with seeders.
#
# A dump names the database it was taken from. TablePlus writes a `use` line and
# `mysqldump --databases` writes CREATE DATABASE and USE. Left in, those
# statements point the import at that database instead of this branch's one and
# overwrite it, so they are stripped and the import can only land where we mean
# it to. Migrations run afterwards because a dump is a snapshot and the branch
# may add migrations on top of it; seeders do not, because the imported rows are
# real data rather than a blank slate.
seed_database() {
    local dir="$1" main="$2" db="$3" dump reader

    if ! dump="$(find_dump "$dir" "$main")"; then
        log "no dump at $DUMP_RELATIVE: migrating fresh with seeders"
        ( cd "$dir" && php artisan migrate:fresh --seed --force ) >>"$LOG" 2>&1
        return
    fi

    reader=cat
    [[ "$(file --mime-type -b "$dump")" == "application/gzip" ]] && reader=gzcat

    log "importing $dump into $db"
    if "$reader" "$dump" \
        | /usr/bin/sed -E '/^[[:space:]]*(USE|CREATE DATABASE|DROP DATABASE)[[:space:]]/I d' \
        | "$MYSQL" -h 127.0.0.1 -u root "$db" 2>>"$LOG"
    then
        ( cd "$dir" && php artisan migrate --force ) >>"$LOG" 2>&1
        log "imported $dump into $db"
    else
        log "import of $dump failed: falling back to a fresh migration"
        ( cd "$dir" && php artisan migrate:fresh --seed --force ) >>"$LOG" 2>&1
    fi
}

provision() {
    local dir="$1" lock state main branch repo site url db base_db owner previous
    state="$(state_file "$dir")"
    lock="$STATE_DIR/$(digest "$dir").lock"

    # One provision per worktree at a time; concurrent hook fires just bail.
    mkdir "$lock" 2>/dev/null || { log "skip $dir: provision already in flight"; return 0; }
    trap 'rmdir "$lock" 2>/dev/null' RETURN

    main="$(main_clone "$dir")"
    [[ -n "$main" && -f "$main/.env" ]] || { log "skip $dir: no main clone .env"; return 1; }

    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    branch="${branch##*/}"
    [[ -n "$branch" && "$branch" != "HEAD" ]] || branch="$(basename "$dir")"

    repo="$(basename "$main")"; repo="${repo%%.*}"
    site="$(slug "$repo-$branch")"

    # Reuse an existing link only when it already points at this worktree.
    owner="$(herd_links | awk -F'\t' -v s="$site" '$1 == s {print $2}')"
    if [[ -n "$owner" && "$owner" != "$dir" ]]; then
        site="$site-$(printf '%s' "$dir" | shasum | cut -c1-6)"
    fi

    # The branch can change inside a worktree; retire the old host if so.
    if [[ -f "$state" ]]; then
        previous="$(grep -E '^SITE=' "$state" | cut -d= -f2-)"
        if [[ -n "$previous" && "$previous" != "$site" ]]; then
            "$HERD" unlink "$previous" >>"$LOG" 2>&1
            log "unlinked $previous (branch changed to $branch)"
        fi
    fi

    url="https://$site.test"
    base_db="$(grep -E '^DB_DATABASE=' "$main/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"' ')"
    [[ -n "$base_db" ]] || base_db="laravel"
    db="$(printf '%s_%s' "$base_db" "$(slug "$branch" | tr '-' '_')" | cut -c1-64)"

    # MAIN is recorded so a teardown can still name the main clone after the
    # worktree it would have been derived from is gone.
    printf 'SITE=%s\nURL=%s\nDB=%s\nBRANCH=%s\nPATH_=%s\nMAIN=%s\nSTATUS=provisioning\n' \
        "$site" "$url" "$db" "$branch" "$dir" "$main" >"$state"

    log "provisioning $dir -> $url (db $db)"

    [[ -f "$dir/.env" ]] || cp "$main/.env" "$dir/.env"
    # Rewritten every run: the branch, and so the host and database, can change.
    /usr/bin/sed -i '' -E "s|^APP_URL=.*|APP_URL=$url|; s|^DB_DATABASE=.*|DB_DATABASE=$db|" "$dir/.env"

    ( cd "$dir" && composer install --no-interaction --quiet ) >>"$LOG" 2>&1
    ( cd "$dir" && { npm ci --silent || npm install --silent; } ) >>"$LOG" 2>&1

    "$MYSQL" -h 127.0.0.1 -u root -e "CREATE DATABASE IF NOT EXISTS \`$db\`" >>"$LOG" 2>&1

    seed_database "$dir" "$main" "$db"
    ( cd "$dir" && php artisan wayfinder:generate --with-form ) >>"$LOG" 2>&1
    ( cd "$dir" && npm run build ) >>"$LOG" 2>&1

    # `herd link` runs a Boost hook that rewrites bundled skill files. Revert
    # only what it touched under .claude/, so the branch diff stays clean.
    local before after
    before="$(git -C "$dir" status --porcelain -- .claude 2>/dev/null)"
    ( cd "$dir" && "$HERD" link "$site" && "$HERD" secure "$site" ) >>"$LOG" 2>&1
    after="$(git -C "$dir" status --porcelain -- .claude 2>/dev/null)"
    if [[ "$before" != "$after" ]]; then
        comm -13 <(printf '%s\n' "$before" | sort) <(printf '%s\n' "$after" | sort) \
            | awk '{print $2}' \
            | while read -r f; do [[ -n "$f" ]] && git -C "$dir" checkout -- "$f" 2>/dev/null; done
        log "reverted Boost edits under .claude in $dir"
    fi

    ( cd "$dir" && php artisan config:clear ) >>"$LOG" 2>&1

    if curl -sk -o /dev/null -w '%{http_code}' "$url" | grep -qE '^(200|30[0-9])$'; then
        /usr/bin/sed -i '' 's/^STATUS=.*/STATUS=ready/' "$state"
        log "ready $url"
        notify "Worktree site ready" "$site.test"
    else
        /usr/bin/sed -i '' 's/^STATUS=.*/STATUS=failed/' "$state"
        log "FAILED $url - see $LOG"
        notify "Worktree site failed" "$site.test - see provision.log"
    fi
}

SETTLED_QUERY="$HOME/.claude/scripts/settled-worktrees.py"

# Worktree paths whose T3 thread is settled. This reads T3's private schema, so
# it fails closed: a missing file, a renamed column or any query error yields
# nothing rather than a guess, which turns the sweep into a no-op.
settled_worktrees() {
    [[ -f "$T3_STATE" && -f "$SETTLED_QUERY" ]] || return 0
    /usr/bin/python3 "$SETTLED_QUERY" "$T3_STATE" 2>/dev/null
}

# Refuse to drop anything that is not one of our per-branch databases. Without a
# main clone to read the base name from there is nothing to check against, so the
# database is kept rather than guessed at.
droppable_database() {
    local db="$1" main="$2" base
    [[ -n "$db" && -n "$main" ]] || return 1
    base="$(grep -E '^DB_DATABASE=' "$main/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\'' ')"
    [[ -n "$base" ]] || return 1
    [[ "$db" != "$base" ]] || return 1
    [[ "$db" == "${base}_"* ]] || return 1
    return 0
}

# A settled worktree is safe to delete only once nothing lives in it that is not
# also on the remote: no uncommitted changes, no untracked files, no unpushed
# commits, and an upstream to have pushed to.
safe_to_delete() {
    local dir="$1" base
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
    [[ -z "$(git -C "$dir" status --porcelain)" ]] || { log "keep $dir: uncommitted or untracked files"; return 1; }

    if git -C "$dir" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        [[ -z "$(git -C "$dir" log '@{u}..HEAD' --oneline)" ]] || { log "keep $dir: unpushed commits"; return 1; }
        return 0
    fi

    # Never pushed is still safe when the branch carries nothing of its own;
    # otherwise those commits exist in this directory and nowhere else.
    base="$(git -C "$dir" symbolic-ref -q --short refs/remotes/origin/HEAD)"
    [[ -n "$base" ]] || base="origin/main"
    git -C "$dir" rev-parse --verify -q "$base" >/dev/null || { log "keep $dir: no upstream and no $base to compare"; return 1; }
    [[ -z "$(git -C "$dir" log "$base..HEAD" --oneline)" ]] || { log "keep $dir: no upstream and commits not on $base"; return 1; }
    return 0
}

# Take down one worktree and everything provisioned alongside it. Returns 1 when
# anything was deliberately kept, so callers can tell a teardown from a no-op.
# The directory being gone already is normal: T3 removes the worktree itself when
# a thread is deleted, and the site and database still have to follow it.
teardown() {
    local dir="$1" dry="${2:-}" state site db main

    state="$(state_file "$dir")"
    site=""; db=""; main=""
    if [[ -f "$state" ]]; then
        site="$(grep -E '^SITE=' "$state" | cut -d= -f2-)"
        db="$(grep -E '^DB=' "$state" | cut -d= -f2-)"
        main="$(grep -E '^MAIN=' "$state" | cut -d= -f2-)"
    fi
    [[ -n "$site" ]] || site="$(herd_links | awk -F'\t' -v p="$dir" '$2 == p {print $1}')"

    if [[ -d "$dir" ]]; then
        main="$(main_clone "$dir")"
        safe_to_delete "$dir" || return 1
    fi

    # Nothing provisioned and nothing left on disk: the sweep has already been
    # here, and saying so again on every session start is just noise.
    [[ -d "$dir" || -n "$site" || -n "$db" ]] || return 1

    if [[ -n "$dry" ]]; then
        printf 'would reap %s\n  site:     %s\n  database: %s\n' "$dir" "${site:-none}" "${db:-none}"
        return 1
    fi

    # The worktree goes first: `git worktree remove` refuses a dirty tree, so
    # it doubles as a last guard, and nothing else is touched if it fails.
    if [[ -d "$dir" ]]; then
        if [[ -z "$main" ]] || ! git -C "$main" worktree remove "$dir" >>"$LOG" 2>&1; then
            log "keep $dir: git worktree remove failed"
            return 1
        fi
    fi

    [[ -n "$site" ]] && "$HERD" unlink "$site" >>"$LOG" 2>&1
    if [[ -z "$db" ]]; then
        :
    elif droppable_database "$db" "$main"; then
        "$MYSQL" -h 127.0.0.1 -u root -e "DROP DATABASE IF EXISTS \`$db\`" >>"$LOG" 2>&1
        log "dropped database $db"
    elif [[ -z "$main" ]]; then
        log "kept database $db: no main clone to check the name against"
    else
        log "kept database $db: outside the per-branch naming scheme"
    fi

    rm -f "$state"
    log "reaped $dir (site ${site:-none})"
    return 0
}

reap() {
    local current="${1:-}" dry="${2:-}" dir reaped=0

    while read -r dir; do
        [[ -n "$dir" ]] || continue
        [[ "$dir" == "$WORKTREE_ROOT"/* ]] || continue
        [[ "$dir" != "$current" ]] || continue
        teardown "$dir" "$dry" && reaped=$((reaped + 1))
    done < <(settled_worktrees)

    [[ "$reaped" -gt 0 ]] && notify "Worktrees reaped" "$reaped settled worktree(s) torn down"
    return 0
}

prune() {
    herd_links | while IFS=$'\t' read -r name path; do
        [[ "$path" == "$WORKTREE_ROOT"/* ]] || continue
        [[ -d "$path" ]] && continue
        "$HERD" unlink "$name" >>"$LOG" 2>&1
        rm -f "$(state_file "$path")"
        log "pruned $name (worktree gone: $path)"
    done
}

# SessionStart sends {"cwd":...}; the worktree events' payload shape is not
# documented, so try the plausible keys and fall back to the process cwd.
# Whatever comes out still has to be under the worktree root to be acted on.
hook_path() {
    /usr/bin/python3 -c '
import json, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    payload = {}
for key in ("worktree_path", "worktreePath", "worktree", "path", "cwd"):
    value = payload.get(key)
    if isinstance(value, dict):
        value = value.get("path")
    if isinstance(value, str) and value:
        print(value)
        break
' 2>/dev/null
}

case "${1:-}" in
    --hook)
        target="$(hook_path)"
        [[ -n "$target" ]] || target="$PWD"
        # The sweep runs from any session, not just one inside a worktree, so
        # settling a thread is enough to get it cleaned up next time you start
        # Claude anywhere.
        nohup "$0" --sweep "$target" >/dev/null 2>&1 &
        exit 0
        ;;
    --sweep)
        target="$2"
        reap "$target"
        prune
        qualifies "$target" || exit 0
        state="$(state_file "$target")"
        if [[ -f "$state" ]]; then
            status="$(grep -E '^STATUS=' "$state" | cut -d= -f2-)"
            branch="$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null)"
            recorded="$(grep -E '^BRANCH=' "$state" | cut -d= -f2-)"
            # Nothing to do unless the last run failed or the branch moved on.
            [[ "$status" == "failed" || "${branch##*/}" != "$recorded" ]] || exit 0
        fi
        provision "$target"
        ;;
    --hook-end)
        target="$(hook_path)"
        [[ -n "$target" ]] || target="$PWD"
        [[ "$target" == "$WORKTREE_ROOT"/* ]] || exit 0
        nohup "$0" --sweep-after-exit "$target" >/dev/null 2>&1 &
        exit 0
        ;;
    --sweep-after-exit)
        target="$2"
        # Stand outside the directory so this sweeper is never its own holder.
        cd / || exit 0
        # Give the ending session time to let go before deleting its cwd.
        for _ in $(seq 1 24); do
            [[ -d "$target" ]] || break
            [[ "$(lsof -a -d cwd -- "$target" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')" == "0" ]] && break
            sleep 5
        done
        # No worktree is excluded here: the session that owned this one is gone.
        reap ""
        prune
        ;;
    --hook-remove)
        target="$(hook_path)"
        [[ -n "$target" && "$target" == "$WORKTREE_ROOT"/* ]] || exit 0
        nohup "$0" --sweep-removed "$target" >/dev/null 2>&1 &
        exit 0
        ;;
    --sweep-removed)
        target="$2"
        # Stand outside the directory so this sweeper is never its own holder.
        cd / || exit 0
        # The hook may arrive either side of the removal, so wait for the
        # directory to go before taking down what was provisioned around it.
        for _ in $(seq 1 24); do
            [[ -d "$target" ]] || break
            sleep 5
        done
        teardown "$target"
        prune
        ;;
    --reap)
        reap "$PWD" "${2:-}"
        ;;
    --status)
        state="$(state_file "$PWD")"
        [[ -f "$state" ]] && cat "$state" || echo "no site for $PWD"
        ;;
    --prune)
        prune
        ;;
    --remove)
        state="$(state_file "$PWD")"
        [[ -f "$state" ]] || { echo "no site for $PWD"; exit 1; }
        # shellcheck disable=SC1090
        . "$state"
        "$HERD" unlink "$SITE"
        rm -f "$state"
        echo "unlinked $SITE (database $DB kept)"
        ;;
    *)
        prune
        provision "$PWD"
        ;;
esac
