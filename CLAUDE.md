# Project instructions

## Narrate before permission prompts

Before any tool call that will trigger a permission prompt (a Bash command,
file write/edit, or other action requiring approval), state in one or two
sentences: what step of the current task you're on, what action you're about
to take, and briefly why. Keep it short — this is a heads-up before the
prompt, not a full explanation.

## Git workflow

GitHub flow, one short-lived branch per story:

- `main` always passes CI. Never commit directly to it once the GitHub remote
  exists; start each story on a branch off `main` named for the story in
  kebab-case (e.g. `collections-ui`, `game-details`).
- Keep the small reviewed commits (one logical change each, tests green at
  every commit, clear message). Don't squash them.
- Open a PR per story so CI runs and there is a review record. Merge with
  **Rebase and merge** (keeps every commit, linear history, no merge commits).
- Once on GitHub, protect `main`: require CI to pass, block force-pushes.
- Never rewrite history that has been pushed.
- Commit messages and PR descriptions carry no Claude attribution lines.
