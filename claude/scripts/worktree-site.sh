#!/usr/bin/env bash
#
# Give every t3 worktree its own Herd site and database, so a branch can be
# opened in a browser without checking it out in the default clone.
#
#   worktree-site.sh              provision $PWD (idempotent)
#   worktree-site.sh --hook       read the hook payload on stdin, detach, provision
#   worktree-site.sh --hook-remove tear down the worktree named on stdin
#   worktree-site.sh --context    one line about $PWD's site, for a hook to inject
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

env_value() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\'' '; }

# T3 creates a worktree before it has named the thread, so the branch can start
# out as a bare hash. A site named from one of those says nothing about the work.
placeholder_branch() { [[ "$1" =~ ^[0-9a-f]{6,}$ ]]; }

# Replace a key in a .env, appending it when the file does not carry it yet. A
# project that leans on a framework default has no line to rewrite, and leaving
# it that way would point the worktree at whatever the default resolves to.
set_env_value() {
    local file="$1" key="$2" value="$3"
    if grep -qE "^$key=" "$file"; then
        /usr/bin/sed -i '' -E "s|^$key=.*|$key=$value|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

mysql_run() {
    local host="$1" port="$2"; shift 2
    "$MYSQL" -h "$host" -P "$port" -u root "$@"
}

# Run an artisan command only when the project actually provides it, so a
# project without the package behind it is skipped instead of logging a failure.
artisan_if_available() {
    local dir="$1" command="$2"; shift 2
    ( cd "$dir" && php artisan "$command" --help ) >/dev/null 2>&1 || return 0
    ( cd "$dir" && php artisan "$command" "$@" ) >>"$LOG" 2>&1
}

npm_run_if_available() {
    local dir="$1" script="$2"
    [[ -f "$dir/package.json" ]] || return 0
    /usr/bin/python3 -c 'import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1])).get("scripts",{}) else 1)' \
        "$dir/package.json" "$script" 2>/dev/null || return 0
    ( cd "$dir" && npm run "$script" ) >>"$LOG" 2>&1
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
# one, otherwise from a fresh migration with seeders. Migrations run after an
# import because a dump is a snapshot and the branch may add migrations on top
# of it; seeders do not, because imported rows are real data rather than a
# blank slate.
seed_database() {
    local dir="$1" main="$2" connection="$3" target="$4" host="$5" port="$6" dump

    dump="$(find_dump "$dir" "$main")" || dump=""

    case "$connection" in
        mysql|mariadb) import_mysql_dump "$dir" "$dump" "$target" "$host" "$port" ;;
        sqlite)        import_sqlite_dump "$dir" "$dump" "$target" ;;
    esac
}

# Provisioning re-runs after a failure, and a failure late in the run (the site
# not answering, say) leaves a database that is already loaded. Filling it again
# would throw away whatever you had been testing against, so only an empty one
# is ever filled.
database_is_empty() {
    local connection="$1" db="$2" host="$3" port="$4" count
    if [[ "$connection" == sqlite ]]; then
        [[ ! -s "$db" ]]
        return
    fi
    count="$(mysql_run "$host" "$port" -N -e \
        "select count(*) from information_schema.tables where table_schema='$db'" 2>/dev/null)"
    [[ "${count:-0}" -eq 0 ]]
}

migrate_fresh() { ( cd "$1" && php artisan migrate:fresh --seed --force ) >>"$LOG" 2>&1; }

# A dump names the database it was taken from. TablePlus writes a `use` line and
# `mysqldump --databases` writes CREATE DATABASE and USE. Left in, those
# statements point the import at that database instead of this branch's one and
# overwrite it, so they are stripped and the import can only land where we mean
# it to.
import_mysql_dump() {
    local dir="$1" dump="$2" db="$3" host="$4" port="$5" reader

    if [[ -z "$dump" ]]; then
        log "no dump at $DUMP_RELATIVE: migrating fresh with seeders"
        migrate_fresh "$dir"
        return
    fi

    reader=cat
    [[ "$(file --mime-type -b "$dump")" == "application/gzip" ]] && reader=gzcat

    log "importing $dump into $db"
    if "$reader" "$dump" \
        | /usr/bin/sed -E '/^[[:space:]]*(USE|CREATE DATABASE|DROP DATABASE)[[:space:]]/I d' \
        | mysql_run "$host" "$port" "$db" 2>>"$LOG"
    then
        ( cd "$dir" && php artisan migrate --force ) >>"$LOG" 2>&1
        log "imported $dump into $db"
    else
        log "import of $dump failed: falling back to a fresh migration"
        migrate_fresh "$dir"
    fi
}

# On sqlite the database is a file, so importing is replacing that file. A dump
# that is not itself a sqlite database cannot be used here: a MySQL dump left in
# place by a project that has since moved to sqlite would otherwise be copied
# over the database and corrupt it.
import_sqlite_dump() {
    local dir="$1" dump="$2" file="$3" kind

    mkdir -p "$(dirname "$file")"

    if [[ -z "$dump" ]]; then
        log "no dump at $DUMP_RELATIVE: migrating fresh with seeders"
        : >"$file"
        migrate_fresh "$dir"
        return
    fi

    kind="$(file --mime-type -b "$dump")"
    if [[ "$kind" == "application/gzip" ]]; then
        gzcat "$dump" >"$file" 2>>"$LOG"
    elif [[ "$kind" == "application/vnd.sqlite3" ]]; then
        cp "$dump" "$file"
    else
        log "dump $dump is $kind, not a sqlite database: migrating fresh instead"
        : >"$file"
        migrate_fresh "$dir"
        return
    fi

    if [[ "$(file --mime-type -b "$file")" == "application/vnd.sqlite3" ]]; then
        ( cd "$dir" && php artisan migrate --force ) >>"$LOG" 2>&1
        log "imported $dump into $file"
    else
        log "dump $dump did not yield a sqlite database: migrating fresh instead"
        : >"$file"
        migrate_fresh "$dir"
    fi
}

provision() {
    local dir="$1" lock state main branch repo site site_branch url owner
    local connection db base_db db_host db_port
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

    # The site and the database keep the names they were first given. T3 renames
    # a thread's branch as the work shifts, and rebuilding these names from the
    # branch on every run would move the URL out from under an open browser tab
    # and abandon the database you had been testing against. The one name that
    # is allowed to change is a site first linked under a placeholder branch,
    # and --sweep relinks that once a real branch name appears.
    site=""; site_branch=""
    if [[ -f "$state" ]]; then
        site="$(env_value "$state" SITE)"
        site_branch="$(env_value "$state" SITE_BRANCH)"
    fi

    # A worktree can already be linked with its state file gone, reaped or from
    # before this script kept one. Adopt that host instead of adding a second
    # one for the same directory, and treat its name as already settled.
    if [[ -z "$site" ]]; then
        site="$(herd_links | awk -F'\t' -v p="$dir" '$2 == p {print $1}' | head -1)"
        [[ -n "$site" ]] && site_branch="$branch"
    fi

    if [[ -z "$site" ]]; then
        site="$(slug "$repo-$branch")"
        site_branch="$branch"

        # Reuse an existing link only when it already points at this worktree.
        owner="$(herd_links | awk -F'\t' -v s="$site" '$1 == s {print $2}')"
        if [[ -n "$owner" && "$owner" != "$dir" ]]; then
            site="$site-$(printf '%s' "$dir" | shasum | cut -c1-6)"
        fi
    fi

    url="https://$site.test"

    # How a worktree gets its own database depends on what the project runs on.
    # On MySQL that is a database named after the branch; on sqlite the database
    # is a file, and a worktree is already a separate directory, so it gets one
    # for free. Anything else is left alone rather than guessed at: a wrong
    # guess here writes to a database the project does use.
    connection="$(env_value "$main/.env" DB_CONNECTION)"
    [[ -n "$connection" ]] || connection=mysql
    db_host="$(env_value "$main/.env" DB_HOST)"; [[ -n "$db_host" ]] || db_host=127.0.0.1
    db_port="$(env_value "$main/.env" DB_PORT)"; [[ -n "$db_port" ]] || db_port=3306

    db="$([[ -f "$state" ]] && env_value "$state" DB)"

    case "$connection" in
        mysql|mariadb)
            base_db="$(env_value "$main/.env" DB_DATABASE)"
            [[ -n "$base_db" ]] || base_db="laravel"

            # With no state file the worktree's own .env is the record of which
            # database it has been using, so adopt that rather than naming a
            # fresh one and stranding the data already in it. The main clone's
            # own database is never adopted: seeding would run against it.
            if [[ -z "$db" && -f "$dir/.env" ]]; then
                db="$(env_value "$dir/.env" DB_DATABASE)"
                [[ "$db" != "$base_db" ]] || db=""
            fi

            [[ -n "$db" ]] || db="$(printf '%s_%s' "$base_db" "$(slug "$branch" | tr '-' '_')" | cut -c1-64)"
            ;;
        sqlite)
            # Absolute, so a main clone pointing at its own file cannot make the
            # worktree share it once the .env is copied across.
            db="$dir/database/database.sqlite"
            ;;
        *) db="" ;;
    esac

    case "$connection" in
        mysql|mariadb|sqlite) ;;
        *)
            log "$dir: DB_CONNECTION=$connection is not handled, leaving the database alone"
            ;;
    esac

    # MAIN is recorded so a teardown can still name the main clone after the
    # worktree it would have been derived from is gone, and CONNECTION so it
    # knows whether DB names a database to drop or a file that goes with it.
    printf 'SITE=%s\nSITE_BRANCH=%s\nURL=%s\nCONNECTION=%s\nDB=%s\nDB_HOST=%s\nDB_PORT=%s\nBRANCH=%s\nPATH_=%s\nMAIN=%s\nSTATUS=provisioning\n' \
        "$site" "$site_branch" "$url" "$connection" "$db" "$db_host" "$db_port" "$branch" "$dir" "$main" >"$state"

    log "provisioning $dir -> $url ($connection ${db:-none})"

    [[ -f "$dir/.env" ]] || cp "$main/.env" "$dir/.env"
    # Rewritten every run: the branch, and so the host and database, can change.
    set_env_value "$dir/.env" APP_URL "$url"
    [[ -n "$db" ]] && set_env_value "$dir/.env" DB_DATABASE "$db"

    ( cd "$dir" && composer install --no-interaction --quiet ) >>"$LOG" 2>&1
    [[ -f "$dir/package.json" ]] && ( cd "$dir" && { npm ci --silent || npm install --silent; } ) >>"$LOG" 2>&1

    if [[ -n "$db" ]]; then
        [[ "$connection" == sqlite ]] || mysql_run "$db_host" "$db_port" -e "CREATE DATABASE IF NOT EXISTS \`$db\`" >>"$LOG" 2>&1
        if database_is_empty "$connection" "$db" "$db_host" "$db_port"; then
            seed_database "$dir" "$main" "$connection" "$db" "$db_host" "$db_port"
        else
            log "database $db already has content: leaving it alone"
        fi
    fi

    artisan_if_available "$dir" wayfinder:generate --with-form
    npm_run_if_available "$dir" build

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
    base="$(env_value "$main/.env" DB_DATABASE)"
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
    local dir="$1" dry="${2:-}" state site db main connection db_host db_port

    state="$(state_file "$dir")"
    site=""; db=""; main=""; connection=""; db_host=127.0.0.1; db_port=3306
    if [[ -f "$state" ]]; then
        site="$(env_value "$state" SITE)"
        db="$(env_value "$state" DB)"
        main="$(env_value "$state" MAIN)"
        connection="$(env_value "$state" CONNECTION)"
        db_host="$(env_value "$state" DB_HOST)"; [[ -n "$db_host" ]] || db_host=127.0.0.1
        db_port="$(env_value "$state" DB_PORT)"; [[ -n "$db_port" ]] || db_port=3306
    fi
    # A sqlite database is a file inside the worktree, so it has already gone
    # wherever the worktree went and there is nothing separate to drop.
    [[ "$connection" == sqlite ]] && db=""
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
        mysql_run "$db_host" "$db_port" -e "DROP DATABASE IF EXISTS \`$db\`" >>"$LOG" 2>&1
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

# Move a site that was linked under a placeholder branch onto the real branch
# name, once T3 has settled on one. Only the host moves: the database keeps its
# name so nothing that was seeded into it is stranded.
relink_site() {
    local dir="$1" state site branch old_site url

    state="$(state_file "$dir")"
    [[ -f "$state" ]] || return 0
    old_site="$(env_value "$state" SITE)"
    placeholder_branch "$(env_value "$state" SITE_BRANCH)" || return 0

    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    branch="${branch##*/}"
    [[ -n "$branch" && "$branch" != "HEAD" ]] || return 0
    placeholder_branch "$branch" && return 0

    site="$(slug "$(basename "$(env_value "$state" MAIN)" | cut -d. -f1)-$branch")"
    [[ -n "$site" && "$site" != "$old_site" ]] || return 0

    url="https://$site.test"
    ( cd "$dir" && "$HERD" link "$site" && "$HERD" secure "$site" ) >>"$LOG" 2>&1 || return 0
    [[ -n "$old_site" ]] && "$HERD" unlink "$old_site" >>"$LOG" 2>&1

    [[ -f "$dir/.env" ]] && set_env_value "$dir/.env" APP_URL "$url"
    ( cd "$dir" && php artisan config:clear ) >>"$LOG" 2>&1
    /usr/bin/sed -i '' -E "s|^SITE=.*|SITE=$site|; s|^SITE_BRANCH=.*|SITE_BRANCH=$branch|; s|^URL=.*|URL=$url|" "$state"

    log "relinked $old_site -> $site (branch named)"
    notify "Worktree site renamed" "$site.test"
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
            # The site and database names no longer follow the branch, so a
            # rename is not a reason to build anything again. Only a run that
            # did not finish is.
            relink_site "$target"
            [[ "$(env_value "$state" STATUS)" == "failed" ]] || exit 0
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
    --context)
        # Read by a synchronous hook, so it does no work beyond one file read:
        # the URL is whatever the last provisioning run settled on.
        target="$(hook_path)"
        [[ -n "$target" ]] || target="$PWD"
        state="$(state_file "$target")"
        [[ -f "$state" ]] || exit 0
        url="$(env_value "$state" URL)"
        [[ -n "$url" ]] || exit 0
        case "$(env_value "$state" STATUS)" in
            ready) printf 'This worktree is served at %s (database %s). Use it to check changes in a browser.\n' \
                       "$url" "$(env_value "$state" DB)" ;;
            failed) printf 'This worktree'"'"'s site %s failed to provision; see %s.\n' "$url" "$LOG" ;;
            *) printf 'This worktree is being provisioned at %s.\n' "$url" ;;
        esac
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
        site="$(env_value "$state" SITE)"
        db="$(env_value "$state" DB)"
        "$HERD" unlink "$site"
        rm -f "$state"
        echo "unlinked $site"
        [[ -n "$db" ]] && echo "database $db kept"
        ;;
    *)
        prune
        provision "$PWD"
        ;;
esac
