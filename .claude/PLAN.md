# Plan / backlog

Nothing is in flight. Finished plans are archived in `.claude/plan_archives/`
(`igdb-game.md`, `collections.md`); what's built is indexed in
`.claude/HISTORY.md`; current status and next steps are in
`.claude/HANDOFF.md`. When the next feature is scoped, write its plan here.

## Backlog

One-line prompts to flesh out when ready; not scheduled.

- **Richer game panel data** — widen IGDB's `SEARCH_FIELDS` and add columns
  for screenshots/artworks, ratings, developer/publisher, trailers, storyline,
  websites, similar games (could link to other game pages). Each its own
  migration and commit.
- **UI polish pass** — collection show/search markup is unstyled (platform
  picker beside Add, etc.). Needed before making the repo public.
- **Reuse `games/_search`** elsewhere (e.g. a review form) via a different
  `action_partial`.
- **Auth hardening** — advanced rate limiting/lockout and email
  verification; see `.claude/workflow/20260731-144252/future-story-auth-hardening.md`.

## Before making the GitHub repo public

- A real `README.md` (what it is, screenshots, how to run it).
- A `LICENSE` decision. No file means all rights reserved, which suits a
  possible commercial product; avoid MIT/Apache unless that's intended.
- The UI polish pass above.
- Decide whether `.claude/` (handoff, plans, workflow retros) is published.
- Then turn on branch protection for `main` (free on public repos; on a
  private free repo the API returns 403 "Upgrade to GitHub Pro", tried
  2026-10-08). Put this JSON in a file and run
  `gh api -X PUT repos/jasonbgarland/ruby_gaming/branches/main/protection --input <file>`:

  ```json
  {
    "required_status_checks": { "strict": true,
      "contexts": ["scan_ruby", "scan_js", "lint", "test", "system-test"] },
    "enforce_admins": true,
    "required_pull_request_reviews": null,
    "restrictions": null,
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false
  }
  ```

  Until then the rule in `CLAUDE.md` (no direct commits to `main`) is the
  only guard.
