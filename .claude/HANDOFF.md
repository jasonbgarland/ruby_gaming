# Project handoff / status

Last updated: 2026-10-23

## What this project is

`ruby_gaming` — a Rails 8.1 app for a gaming website: user accounts, IGDB
game search, and per-user game collections (a game + the platform you
want/own it on). No scores/leaderboards/matches yet. Long-term it is meant
to grow into a larger demo project hosted on the web, possibly commercial.

## What's built

Items 1–25 (scaffold → accounts → IGDB client → Postgres → collections →
system tests → live search → GitHub + CI → game details page → richer IGDB
details → demo seeds → UI polish → portfolio README → going public) are in
**`.claude/HISTORY.md`**, with commit hashes. The backlog is in `.claude/PLAN.md`.

Facts worth having up front:
- Every controller requires login by default (`Authentication` concern in
  `ApplicationController`); opt out with `allow_unauthenticated_access`.
- Needs local Postgres: `brew services start postgresql@17`.
- Tests: `bin/rails test` (no browser) and `bin/rails test:system`
  (Capybara + headless Chrome); commands are in `README.md`. Tests use fake
  IGDB credentials (`test/test_helper.rb`), so they don't need
  `config/master.key`.
- Repo: **public** `github.com/jasonbgarland/ruby_gaming` (since 2026-10-23,
  pinned on the GitHub profile), branch `main`. CI
  (`.github/workflows/ci.yml`: Brakeman + bundler-audit, importmap audit,
  RuboCop, tests, system tests) passes. Dependabot checks monthly; minor and
  patch bumps arrive as one grouped PR, majors separately. Only "Rebase and
  merge" is enabled on the repo.
- Git workflow (branch per story, PR, rebase-and-merge, no direct commits to
  `main`, no Claude attribution lines) is written in `CLAUDE.md`. **Branch
  protection is on** for `main`: the five CI jobs must pass and the branch must
  be up to date, history stays linear, no force-pushes or deletions, and
  admins are included. So every change, docs too, goes through a PR, and a
  PR must be rebased onto `main` before it can merge. No reviews are required
  (a solo repo). The payload is in `.claude/PLAN.md`.

State at last update: `main` is public with the portfolio README (HISTORY items
24 and 25); 200 regular tests + 15 system tests green. Sprint 1 is complete.

## Explicitly deferred (not built yet)

Details are in the `.claude/PLAN.md` backlog ("Auth hardening"):
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

Sprint 1 is done; nothing is in flight. Pick one:

1. **Product-direction discussion** (the user wants it first): what the site
   is for, what data we own (reviews, ratings, tags, play status) versus rely
   on IGDB for. It decides the screenshots/trailer story, tags/keywords and
   discovery. See `.claude/PLAN.md` backlog.
2. **Visual theme and front-end pass** (later UX sprint): an overall theme and
   color scheme (sign-in has none), the default blue/purple link colors, the
   other plain pages. See "Site-wide UI polish" in `PLAN.md`.
3. **Small cleanups** from "Open items" below, e.g. removing the redundant
   `/games/search` Add.

Optional polish on the public repo: a one-line About description and topics
(`rails`, `hotwire`) on the GitHub repo page.

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
- `image_processing` 2.x (updated 2026-10-08) no longer pulls in an image
  backend, and nothing uses Active Storage variants yet. When we add uploads,
  add `gem "ruby-vips"` explicitly (Rails defaults to vips; CI already
  installs `libvips`). The gem could also be dropped until then.
- The repo's encrypted credentials hold the real IGDB client secret. That is
  safe while `config/master.key` stays private; rotate the Twitch client
  secret if the key is ever exposed.
