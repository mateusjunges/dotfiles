import sqlite3, sys

try:
    con = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    columns = {r[1] for r in con.execute("pragma table_info(projection_threads)")}
    if not {"settled_at", "worktree_path", "deleted_at"}.issubset(columns):
        sys.exit(0)
    rows = con.execute(
        "select distinct worktree_path from projection_threads "
        "where settled_at is not null and worktree_path is not null and deleted_at is null"
    ).fetchall()
except Exception:
    sys.exit(0)

for (path,) in rows:
    if path:
        print(path)
