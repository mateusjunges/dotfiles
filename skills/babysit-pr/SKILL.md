---
name: babysit-pr
description: Monitor a pull request through review and CI. Use when the user asks to monitor, watch, or babysit a PR.
metadata:
  harness: [claude, codex]
  platform: [darwin, linux]
---

# Babysit PR
Various repos we work in have AI review bots. They are helpful, even if they are not always right.

## Watching

Before watching, go through the PR's current comments and checks yourself. The watcher only reports what happens after its first start.

Then watch the PR with the bundled script instead of writing your own poll loop:

```bash
~/.dotfiles/skills/babysit-pr/watch.sh <pr> [--repo <owner/repo>]
```

It blocks until something needs attention, prints the PR URL followed by one line per event, and exits. Events are new comments, reviews and inline comments (except your own), failed or cancelled checks, all checks finishing on the current head, the review decision becoming approved or changes requested, the PR being merged or closed, and the branch conflicting with or falling behind the base branch. It remembers what it already reported for each PR, so anything that happens while it is stopped is reported as soon as it starts again.

In Claude Code, start it with Bash `run_in_background`. Do not use Monitor, which is killed after 30 minutes. A background command runs until it has something to report, and its exit notifies you. In harnesses without background commands, run it in the foreground with the longest timeout available and run it again whenever it times out.

Every time the watcher exits, handle all the events it printed, then start it again before ending your turn. Only leave it stopped when the PR is approved with required checks green, merged, closed, or no longer worth monitoring. If it says a watcher is already running, leave that one alone.

In Claude Code, also schedule a heartbeat when you start watching, in case a restart gets missed. Create a recurring `CronCreate` job every 15 minutes on off minutes (for example `4,19,34,49 * * * *`) with a prompt like: "Babysit check for <pr url>: run `~/.dotfiles/skills/babysit-pr/watch.sh <pr> --repo <owner/repo> --alive`. If it exits 1 and the PR still needs watching, start the watcher again in the background following the babysit-pr skill. Otherwise do nothing and say nothing." Delete the job with `CronDelete` when you stop watching. Cron jobs expire after 7 days, so recreate it if babysitting runs longer.

## Handling events

Only act on checks and comments newer than the latest push. Verify every bot finding against the source before changing code. Fix real findings and CI failures, distinguish repository failures from infrastructure flakes. 

Keep an eye on changes to `main` (or the default branch of on the repo) and rebase when needed. if an overlapping PR makes this obsolete, stop monitoring, report it to the user and ask before closing the PR unless closure was explicitly authorized.

If a review bot leaves feedback you believe is not worth addressing, reply and resolve the comment.

Never reply to comments left by another human. Instead, draft a reply and output it so that I can take a look before acting on it. If a human reviewer asks for changes worth addressing, address them and re-request review from that person.

Do not let review feedback expand the PR beyond the user's original goal. Address real shortcomings, but avoid scope creep.

If nothing was changed, stay quiet rather than posting filler comments. Stop when the review bots and required checks are green on the latest commit. When you stop, make sure no watcher is left running and delete the heartbeat job. Merge only when the user explicitly requested it; otherwise report that the PR is ready.