# Project handoff / status

Last updated: 2026-10-15

## What this project is

`ruby_gaming` — a Rails 8.1 app for a gaming website: user accounts, IGDB
game search, and per-user game collections (a game + the platform you
want/own it on). No scores/leaderboards/matches yet. Long-term it is meant
to grow into a larger demo project hosted on the web, possibly commercial.

## What's built

Items 1–19 (scaffold → accounts → IGDB client → Postgres → collections →
system tests → live search → GitHub + CI → game details page → richer IGDB details part 1) are in **`.claude/HISTORY.md`**,
with commit hashes. Finished plans are in `.claude/plan_archives/`; the
backlog is in `.claude/PLAN.md`.

Facts worth having up front:
- Every controller requires login by default (`Authentication` concern in
  `ApplicationController`); opt out with `allow_unauthenticated_access`.
- Needs local Postgres: `brew services start postgresql@17`.
- Tests: `bin/rails test` (no browser) and `bin/rails test:system`
  (Capybara + headless Chrome); commands are in `README.md`. Tests use fake
  IGDB credentials (`test/test_helper.rb`), so they don't need
  `config/master.key`.
- Repo: **private** `github.com/jasonbgarland/ruby_gaming`, branch `main`.
  CI (`.github/workflows/ci.yml`: Brakeman + bundler-audit, importmap audit,
  RuboCop, tests, system tests) passes. Dependabot checks monthly; minor and
  patch bumps arrive as one grouped PR, majors separately. Only "Rebase and
  merge" is enabled on the repo.
- Git workflow (branch per story, PR, rebase-and-merge, no direct commits to
  `main`, no Claude attribution lines) is written in `CLAUDE.md`. Branch
  protection is **not** enabled: GitHub needs Pro or a public repo for it
  (API payload saved in `.claude/PLAN.md`).

State at last update: on branch `companies` (not yet pushed, no PR), 181
regular tests + 15 system tests expected green; working tree clean.

## Explicitly deferred (not built yet)

See `.claude/workflow/20260731-144252/future-story-auth-hardening.md`:
- Advanced rate-limit/lockout hardening beyond generator defaults.
- Email verification/confirmation of a user's address (needs its own
  design pass).

## Process notes worth remembering

- Default working loop (human preference): small task → run tests → human
  reviews the diff and asks questions → commit. Explain Rails "why" as we go;
  the user is learning and re-asks things on purpose — keep answers short
  and don't deep-dive unprompted. Small, single-purpose commits are the goal
  (many commits is fine; each should keep tests green).
- The formal `/workflow` skill (Plan → Design → Build → Review via crit) is
  worth it only for large/ambiguous work; too much friction for well-scoped
  tasks. `crit <file>` is a good standalone tool for dense reviews.
- Keep all AI-generated artifacts (workflow docs, this handoff) inside
  `.claude/`, not scattered in the repo.
- Add system tests alongside each new UI step instead of backfilling. Put
  rule checks (authorization, validation) in integration tests; reserve
  system tests for behavior that needs a real browser.
- Capybara assertions that something *appears* wait automatically (2s);
  proving something *doesn't* happen can't, so avoid weak `assert_no_*`
  checks (see the `sleep` in the "fewer than 3 characters" system test).
- After an Add the page redirects back with the same search results still
  showing; system tests must not re-search then (it swaps the frame under
  the platform picker — see `search_and_add` in `collections_test.rb`).
- Keep this file to current status and next steps; finished work goes in
  `.claude/HISTORY.md`.
- Docs-only changes also go through a branch + PR now.

## Next steps

1. **Finish the manual browser pass** — only look and feel is left; rules are
   covered by automated tests. Dev server: `bin/rails server` (needs Postgres).
2. **Richer IGDB details, part 2: companies** — in progress on branch
   `companies`. Done (commit `39ca3e2`): `companies` table (unique on
   `lower(name)`) and `game_companies` join with a `role` (developer or
   publisher, unique per game + company + role), models and model tests.
   Decisions: companies match by **name** (the client doesn't return IGDB
   company ids; revisit if renames or same-name clashes show up), and a
   company that both develops and publishes a game gets **two rows**, one per
   role. Still to do, as small commits:
   1. Sync companies in `Game.upsert_from_igdb` (one row per true flag; remove
      stale ones on refresh; `Company` find-or-create by name, case-insensitive).
   2. Show Developer/Publisher in `games/_panel`.
   3. Integration/system test through the game page.
   4. Update HISTORY, PLAN, and delete `.claude/igdb-fields.md` if all of
      Story A is done; open the PR (rebase and merge).
   Field decisions are in `.claude/igdb-fields.md` (temporary).
3. **Product-direction discussion** (the user wants it after part 2): what the
   site is for, what data we own (reviews, ratings, tags, play status) versus
   rely on IGDB for. It decides the screenshots/trailer story, tags/keywords,
   discovery, and the UI polish pass. See `.claude/PLAN.md` backlog.
4. Before making the repo public: README, LICENSE decision, UI polish, then
   branch protection (checklist in `.claude/PLAN.md`).

## Open items / decisions to revisit

- `CollectionsController#destroy` and `CollectionGamesController#destroy`
  both call `destroy` and always report success. Fine today (no
  `before_destroy` callbacks, DB errors raise); add a failure branch (or
  `destroy!`) to **both** when a rule that can block deletion appears.
- The standalone `/games/search` page's Add (bare `Game` upsert, no user
  link) is now redundant: result names link to the game page, which has the
  real add-to-collection form. Remove `GamesController#create`, its route and
  `games/_add_result` when convenient.
- `GamesController#show` is accumulating lookups (game, collections, the
  user's entries). When reviews land, move them into model methods
  (e.g. `Game#entries_for(user)`).
- `collections_flow_test.rb` is one ~30-test file; consider splitting by
  action or read/write if it grows.
- `Game.upsert_from_igdb` is a find-then-save, not an atomic upsert; two
  simultaneous first views of the same new game could race (the unique index
  on `igdb_id` keeps the data safe, but one request would raise). Harden if
  it ever shows up.
- Local `db:migrate` dumps `db/schema.rb` with columns in creation order, but
  the committed file is alphabetical; hand-sort new columns to keep diffs
  clean (and find out why the dump order differs).
- Editor auto-format once un-indented methods under `private`; project
  convention (and Rails') is indented, rubocop allows both.
- CI housekeeping: `ubuntu-latest` moves to Ubuntu 26 on 2026-10-19; if CI
  breaks around then, look there first.
- `image_processing` 2.x (updated 2026-10-08) no longer pulls in an image
  backend, and nothing uses Active Storage variants yet. When we add uploads,
  add `gem "ruby-vips"` explicitly (Rails defaults to vips; CI already
  installs `libvips`). The gem could also be dropped until then.
- GitHub Actions minutes: private repos on the free plan have a monthly
  allowance (believed 2,000 Linux minutes); check
  github.com/settings/billing if runs stop.
