import sqlite3, sys

try:
    con = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    columns = {r[1] for r in con.execute("pragma table_info(projection_threads)")}
    if not {"settled_at", "worktree_path", "deleted_at"}.issubset(columns):
        sys.exit(0)
    # A path is only settled once every live thread on it is. T3 can open a
    # new thread on an existing branch, and that thread inherits the settled
    # thread's worktree; reaping it then deletes the directory out from under
    # the active session, which T3 promptly recreates, and round it goes.
    rows = con.execute(
        "select distinct worktree_path from projection_threads "
        "where settled_at is not null and worktree_path is not null and deleted_at is null "
        "and worktree_path not in ("
        "  select worktree_path from projection_threads "
        "  where settled_at is null and worktree_path is not null and deleted_at is null"
        ")"
    ).fetchall()
except Exception:
    sys.exit(0)

for (path,) in rows:
    if path:
        print(path)
