---
name: file-upload
description: 'Upload local files (screenshots, recordings, logs) to the Cloudflare R2 bucket and get public URLs plus ready-to-paste markdown. Use when a PR description, PR comment, or issue needs images or files embedded, or when the user asks to upload or share a file.'
argument-hint: '<file> [<file>...]'
---

Upload files with the bundled script:

```bash
~/.claude/skills/file-upload/upload.sh [--prefix <dir>] <file> [<file>...]
```

Each successful upload prints one tab-separated line: the local path, the public URL, and a markdown snippet. Images get `![name](url)`, everything else gets a `[name](url)` link. The script exits non-zero if any file failed, so read stderr and report failures instead of pasting broken links.

Objects are stored as `<prefix>/<YYYY>/<MM>/<random>-<filename>`. The prefix defaults to the current git repository name, so run the script from inside the repo the PR belongs to, or pass `--prefix` explicitly.

## Using it in PR descriptions

1. Capture or locate the files first (screenshots, screen recordings, etc.). Use absolute paths.
2. Upload them in a single call so the output lines up with the order you passed them in.
3. Paste the markdown snippets into the PR body where they belong, usually next to the paragraph describing that change. Give each image a meaningful alt text by editing the label in the snippet if the filename is not descriptive.
4. Pass the body to `gh pr create --body-file` or `gh pr edit --body-file` rather than inlining it, so the markdown is not mangled by shell quoting.

GitHub does not render `<video>` tags pointing at external hosts, so videos can only be linked. If a recording should play inline, convert it to a GIF first (for example with `ffmpeg`) and upload the GIF.

## Things to keep in mind

Uploaded files are public to anyone with the URL. The random segment makes them unguessable, but never upload secrets, credentials, `.env` files, or screenshots showing customer data or tokens. If a screenshot might contain sensitive information, check it before uploading.

## Setup

The script reads these variables from the environment, falling back to `~/.config/file-upload/config` (plain `KEY=value` lines, kept outside the dotfiles repo):

```bash
R2_ACCOUNT_ID=...          # Cloudflare account ID
R2_ACCESS_KEY_ID=...       # R2 API token access key (Object Read & Write, scoped to the bucket)
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=...
R2_PUBLIC_URL=https://...  # custom domain or r2.dev URL serving the bucket publicly
```

If a variable is missing the script says which one. Tell the user rather than trying to create credentials yourself.
