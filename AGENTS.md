# Agent steering (this repo)

## Git / remotes

- **Default:** do **not** `git push` (or delete/update remote refs) unless the user **explicitly** says to (e.g. “push to origin”, “push `dev`”, “delete remote branch …”).
- **Local commits:** only when the user explicitly asks to commit/checkpoint (or confirms a checkpoint if this project uses that flow).

See `.cursor/rules/git-no-push-default.mdc` for the canonical wording.
