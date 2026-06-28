---
name: update-docs
description: Update `.claude/CLAUDE.md` and `README.md` to reflect the current state of the project. Use after changes that may have made the docs stale or when the user asks to refresh the docs.
---

Update both `.claude/CLAUDE.md` and `README.md` so they accurately reflect the current state of the project. Do not commit the changes.

**Start from what changed.** Run `git diff main...HEAD` (and check uncommitted changes) to see what's new or moved, then map those changes to the doc sections they affect — the GraphQL Domains table, the commands list, the architecture/provider order, file paths, env vars. This keeps the pass targeted instead of re-deriving the whole project. If invoked with no relevant diff, fall back to a full read-through.

**Source files are the source of truth — not the docs.** Read whatever you need to confirm the actual structure before editing, then fix gaps, inaccuracies, and outdated content.

Keep the same tone and formatting style as the existing content. Edit only what is wrong or missing.
