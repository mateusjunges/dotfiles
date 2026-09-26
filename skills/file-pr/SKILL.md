---
name: file-pr
description: File a concise pull request. Use when the user asks to file, open, or create a PR.
metadata:
  harness: [claude, codex]
  platform: [darwin, linux]
---

# File PR
Before filing, check whether a PR for this branch already exists. Review the diff locally against the default branch to make sure its content match the goal.

PR titles usually become commit messages, so follow the repository title conventions. Look at recently merged PRs and git history for examples. Prefer a concise, human-readable title that explains why the change matters. 

Check whether the repository has a PR template and if it does, follow it.

Open the description with a simple explanation of the problem based on the user's original prompt, then briefly explain the solution. Do not lead with an implementation inventory.

Open a real PR rather than a draft so review bots run.