# Project handoff / status

Last updated: 2026-10-08

## What this project is

`ruby_gaming` — a Rails 8.1 app for a gaming website: user accounts, IGDB
game search, and per-user game collections (a game + the platform you
want/own it on). No scores/leaderboards/matches yet.

## What's built

Everything below is complete; detail (design rationale, test counts,
verification) lives in git history — `git show <hash>` or `git log --oneline
-- <path>`. This is a short index, not a replacement for the commits.

1. **Initial scaffold** (`960dbea`) — vanilla Rails 8 app, Docker/Kamal
   deploy config present but not configured for a real target yet.
2. **User accounts** (`d0f9580`, paper trail in
   `.claude/workflow/20260731-144252/`) — sign up/login (username or
   email)/settings/password reset via Rails 8's `generate authentication`;
   `users` + `sessions` (DB-backed); generator-default rate limiting.
   `ApplicationController` includes `Authentication`, so **every controller
   requires login by default** (opt out with `allow_unauthenticated_access`).
3. **Claude Code project config** (`fb6dc29`) — `.claude/` settings,
   `CLAUDE.md`.
4. **IGDB client + credentials** (`8589e19`, `411334b`) —
   `app/services/igdb_client.rb`: Twitch OAuth client-credentials flow
   (cached token), `#search`/`#find` against IGDB's `/games`, returns
   `IgdbClient::Game` value objects. Real credentials in encrypted
   credentials; live smoke test: `RUN_IGDB_INTEGRATION=1 bin/rails test
   test/services/igdb_client_live_test.rb`.
5. **Postgres** (`251aed5`) — replaced SQLite for native array/GIN columns.
   Needs local Postgres (`brew services start postgresql@17`);
   `test/test_helper.rb` disables parallel test workers on macOS only
   (Homebrew Postgres isn't fork-safe).
6. **`Game` model** — `games` table (`igdb_id` unique, `platforms`/`genres`
   arrays, `refreshed_at`); `.find_or_refresh(igdb_id)` is the on-read
   refresh entry point (24h staleness).
7. **Standalone search page** — `GamesController#search`/`#create`
   (`/games/search`): live IGDB search; Add just upserts a bare `Game` with
   no user link (an iterative artifact kept to validate behavior; revisit).
8. **`Collection` / `CollectionGame` models** (`3e0f956`) — per-user
   collections; join model carries `platform`, validated against the
   game's IGDB platforms, unique per `(collection, game, platform)`. Design
   and decisions: `.claude/PLAN.md`.
9. **Collections CRUD UI** (`47499b4`…`d62f7a1`) — index/show/new/edit/
   destroy + nav link. `CollectionsController` scopes everything through
   `Current.user.collections` (other users' ids 404).
10. **Generic search partial** (`4da13ae`) — `games/_search.html.erb`.
    Locals: `url`, `query`, `results`, `action_partial` (a partial rendered
    once per result with `result`/`query` locals — the caller's own action).
11. **System (browser) tests** (`1ac16f2`) — Capybara + headless Chrome in
    `test/system/collections_test.rb`; `bin/rails test:system` (plain
    `bin/rails test` skips them). `README.md` now lists dev commands.
12. **Add/remove games in a collection** (`3c96568`, `c59ec00`) — nested
    `collection_games` routes (create, destroy);
    `CollectionGamesController` loads the collection via
    `Current.user.collections`. The collection show page embeds the search
    partial with `collection_games/_add_result` (platform dropdown + Add);
    Remove button per row. Buttons inside the search frame use
    `turbo_frame: "_top"` so the redirect reloads the whole page and the
    flash shows.
13. **Live search-as-you-type** (`a8c1fc1`) — Stimulus `autosubmit`
    controller debounces (300ms) and auto-submits only from 3 characters
    (`data-autosubmit-min-length-value`); Enter/Search always searches.
    The search **form sits outside** the `game-search` Turbo Frame and
    targets it (`data-turbo-frame`), so a swap replaces only the results
    and the text box keeps focus. The 3-char rule is client-side only (the
    server has no minimum).

State at last update: 153 regular tests + 7 system tests green; working
tree clean. **Not yet done: a manual browser pass of the new collection
add/remove + live search** (the user was doing this at lunch).

## Explicitly deferred (not built yet)

See `.claude/workflow/20260731-144252/future-story-auth-hardening.md`:
- Advanced rate-limit/lockout hardening beyond generator defaults.
- Email verification/confirmation of a user's address (needs its own
  design pass).

## Process notes worth remembering

- Default working loop (human preference): small task → run tests → human
  reviews the diff and asks questions → commit. Explain Rails "why" as we go;
  the user is learning and re-asks things on purpose — keep answers short
  and don't deep-dive unprompted.
- The formal `/workflow` skill (Plan → Design → Build → Review via crit) is
  worth it only for large/ambiguous work; too much friction for well-scoped
  tasks. `crit <file>` is a good standalone tool for dense reviews.
- Keep all AI-generated artifacts (workflow docs, this handoff) inside
  `.claude/`, not scattered in the repo.
- Add system tests alongside each new UI step instead of backfilling.
- Capybara assertions that something *appears* wait automatically (2s);
  proving something *doesn't* happen can't, so avoid weak `assert_no_*`
  checks (see the `sleep` in the "fewer than 3 characters" system test).

## Next steps (after lunch)

1. **Manual browser pass** of: collection CRUD incl. the Delete confirm,
   search on a collection page, Add (platform picker, duplicate error, bad
   platform), Remove, and live typing keeping the cursor in the box. Dev
   server: `bin/rails server` (needs Postgres).
2. **Put the repo on GitHub.** Today there is **no remote** and only a
   `main` branch (27 commits). `gh` CLI is installed (`gh repo create`).
   Decide public vs. private first. `.github/workflows/ci.yml` (Rails
   default) and `dependabot.yml` exist and will run on the first push, but
   **CI will fail as written**; fix before/with the first push:
   - `test` and `system-test` jobs have no Postgres service (the `services:`
     block is a commented-out Redis template from the SQLite era) — add a
     `postgres` service and the DB env vars `config/database.yml` expects.
   - `RAILS_MASTER_KEY` is commented out; `IgdbClient.new` needs the
     credentials even though tests stub HTTP — add it as a repo secret
     (verify whether tests really need it; a test-only credentials file is
     the alternative).
   - The workflow's `system-test` job runs `test:system` (Chrome is on the
     ubuntu runner); only local `bin/ci` / `config/ci.rb` skips system tests.
3. **Brainstorm a branching strategy** (discussion first, not decided):
   e.g. one branch per "story" (feature branch off `main`) holding the small
   reviewed commits, then merge via PR with squash vs. merge-commit vs.
   rebase. Trade-off to weigh: our small commits are easy to review one by
   one, which squashing would collapse. Possible fit: branch per story
   (e.g. "collections UI"), keep commits, PR for the CI + a review record,
   branch protection on `main` once on GitHub.

## Open items / decisions to revisit

- `CollectionsController#destroy` and `CollectionGamesController#destroy`
  both call `destroy` and always report success. Fine today (no
  `before_destroy` callbacks, DB errors raise); add a failure branch (or
  `destroy!`) to **both** when a rule that can block deletion appears.
- The standalone `/games/search` Add (bare `Game` upsert, no user link) is
  an iterative artifact; revisit or remove.
- Collection show/search markup is unstyled (platform picker next to Add,
  etc.) — a UI polish pass is intentionally later.
- `collections_flow_test.rb` is one ~30-test file; consider splitting by
  action or read/write if it grows. `IgdbClient`'s header comment still says
  "not yet wired into the app" (stale).
- Editor auto-format once un-indented methods under `private`; project
  convention (and Rails') is indented, rubocop allows both.
- Backlog ideas (see `.claude/PLAN.md`): game details page (`games#show`)
  showing which collections a game is in; reuse `games/_search` elsewhere
  (e.g. a review form) via a different `action_partial`.
