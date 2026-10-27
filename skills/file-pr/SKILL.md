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

## Description
The reviewer will read the diff. The description is for what the diff can't tell them: why the change exists, and anything they would otherwise miss.

Open with the problem in one or two sentences, based on the user's original prompt, then say what the change does about it in one or two more. For most PRs that is the whole description. Add a short paragraph only for something a reviewer must know and won't easily see in the code, such as who gains or loses access to something, a removed route or setting, a migration or deploy step, or a trade-off they might want to push back on.

Leave out:
- A walkthrough of the changes, screen by screen or file by file, even when written as prose.
- What did not change, or reassurance that code was only moved.
- Implementation details the code already shows, including things the framework gives for free.
- Docs or tests that were added or updated.
- How to test it.

Keep it under 150 words, not counting a template's fixed sections or screenshots. Before filing, reread the draft and delete every sentence the reviewer wouldn't miss. If it is still too long, cut more rather than adding headings.

Open a real PR rather than a draft so review bots run.
