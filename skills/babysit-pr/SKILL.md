---
name: babysit-pr
description: Monitor a pull request through review and CI. Use when the user asks to monitor, watch, or babysit a PR.
metadata:
  harness: [claude, codex]
  platform: [darwin, linux]
---

# Babysit PR
Various repos we work in have AI review bots. They are helpful, even if they are not always right.

If your harness offers tools to monitor a PR, use them so you can act when comments arrive. Otherwise, poll the PR for new comments and checks.

Only act on checks and comments newer than the latest push. Verify every bot finding against the source before changing code. Fix real findings and CI failures, distinguish repository failures from infrastructure flakes. 

Keep an eye on changes to `main` (or the default branch of on the repo) and rebase when needed. if an overlapping PR makes this obsolete, stop monitoring, report it to the user and ask before closing the PR unless closure was explicitly authorized.

If a review bot leaves feedback you believe is not worth addressing, reply and resolve the comment.

Never reply to comments left by another human. Instead, draft a reply and output it so that I can take a look before acting on it. If a human reviewer asks for changes worth addressing, address them and re-request review from that person.

Do not let review feedback expand the PR beyond the user's original goal. Address real shortcomings, but avoid scope creep.

If nothing was changed, stay quiet rather than posting filler comments. Stop when the review bots and required checks are green on the latest commit. Merge only when the user explicitly requested it; otherwise report that the PR is ready.