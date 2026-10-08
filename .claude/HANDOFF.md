# Project handoff / status

Last updated: 2026-10-06

## What this project is

`ruby_gaming` — a Rails 8.1 app for a gaming website. So far it is
**scaffold + auth only**; no gaming-specific domain model (games, scores,
leaderboards, matches, etc.) exists yet.

## What's built

Items 1–7 below are complete and their full implementation detail (design
rationale, exact test counts, verification steps) lives in git history —
`git show <hash>` or `git log --all --oneline -- <path>`. This is a
short index, not a replacement for the commits.

1. **Initial scaffold** (`960dbea`) — vanilla Rails 8 app, Docker/Kamal
   deploy config present but not configured for a real target yet.
2. **User accounts** (`d0f9580`, paper trail in
   `.claude/workflow/20260731-144252/`) — sign up/login (username or
   email)/settings/password reset via Rails 8's `generate authentication`
   generator; `users` + `sessions` (DB-backed) tables; generator-default
   rate limiting.
3. **Claude Code project config** (`fb6dc29`) — `.claude/` settings,
   `CLAUDE.md`.
4. **IGDB client + credentials** (`8589e19`, `411334b`; paper trail in
   `.claude/workflow/20260917-133340/`) — `app/services/igdb_client.rb`:
   Twitch OAuth client-credentials flow (cached token), `#search`/`#find`
   against IGDB's `/games` endpoint, returns `IgdbClient::Game` value
   objects. Real working credentials in encrypted credentials, verified
   against the live API (`RUN_IGDB_INTEGRATION=1 bin/rails test
   test/services/igdb_client_live_test.rb`).
5. **Primary database switched from SQLite to Postgres** (`251aed5`) —
   needed for native array/GIN-index columns (`Game.platforms`/`genres`).
   Requires local Postgres running (`brew services start postgresql@17`);
   `test/test_helper.rb` has a macOS-only parallel-test-forking
   workaround (Homebrew's Postgres build isn't fork-safe with Rails'
   default parallel workers — inert on Linux/CI).
6. **`Game` model** — `games` table (`igdb_id` unique, `platforms`/
   `genres` as Postgres arrays w/ GIN indexes, `refreshed_at` for
   staleness); `app/models/game.rb` `#stale?`/`.upsert_from_igdb`/
   `.find_or_refresh(igdb_id, client:)` (the on-read refresh entry point
   later features build on); `IgdbClient#find(igdb_id)` added alongside
   `#search`.
7. **Search page** — `GamesController#search` (live IGDB text search,
   no persistence) / `#create` (`Game.find_or_refresh` + redirect with
   flash), both auth-required; `app/views/games/search.html.erb`.
   Verified against the live IGDB API via `curl` against a running dev
   server (no browser-automation tool available in this environment).

8. **`Collection` model — model layer only** (`3e0f956`) — built as a
   direct conversation (no `/workflow`), continuing the process change
   from Runs 2–3. `Collection` (title/description, per-user) and
   `CollectionGame` (join model: `collection_id`/`game_id`/`platform`,
   validated against that game's actual IGDB platforms) plus matching
   `User`/`Game` associations. **Full design, decisions, and remaining
   scope are the living content of `.claude/PLAN.md` — read that, not
   this entry, for detail.**

9. **Collections CRUD UI** (`47499b4`, `22aad98`, `c9c84b5`, `4bcde92`,
   `ce29b2f`, `d62f7a1`) — built as six small tasks, each reviewed and
   committed separately (index, show, new/create, edit/update, destroy,
   nav link). `CollectionsController` scopes every lookup through
   `Current.user.collections` (other users' ids 404); shared
   `collections/_form.html.erb`; tests in
   `test/integration/collections_flow_test.rb`. Show page lists a
   collection's games+platforms but nothing can add one yet (see step 3
   below).

10. **Generic search partial** (`4da13ae`) — `games/_search.html.erb`: the
    search form + IGDB results inside a `game-search` Turbo Frame. Locals:
    `url`, `query`, `results`, `action_partial` (a partial name rendered
    once per result with `result`/`query` locals — the caller's own
    action). Standalone `/games/search` uses it with
    `games/_add_result.html.erb` (Add button uses `turbo_frame: "_top"` so
    the redirect reloads the full page and the flash shows).

## Explicitly deferred (not built yet)

See `.claude/workflow/20260731-144252/future-story-auth-hardening.md`:
- Advanced rate-limit/lockout hardening beyond generator defaults
  (configurable thresholds, account lockout, CAPTCHA, IP throttling,
  persistent non-cache-store rate-limit tracking).
- Email verification/confirmation of a user's address — not part of the
  Rails 8 generator's default output; would need its own bespoke
  design/plan pass.

## Process notes worth remembering (from retro.md)

- This project uses the `workflow` skill (Plan → Design → Build → Review
  with human gates via crit) for non-trivial feature work — worth reusing
  for the next feature rather than ad-hoc implementation.
- Review previously caught a real bug (duplicate flash-message rendering)
  that Build's own report didn't mention — Review re-verifies independently
  rather than trusting Build's account, and that paid off once already.
- Human preference: keep all AI-generated artifacts (workflow docs, this
  handoff, etc.) inside `.claude/`, not scattered elsewhere in the repo or
  in Claude Code's global cross-project memory system.
- Human preference (2026-09-17, after using `/workflow` for Run 1): the
  formal Plan→Design→Build→Review pipeline is worth its overhead for
  large/ambiguous work or when the artifacts have lasting reference value,
  but is more friction than it's worth for well-scoped, single-deliverable
  tasks — too much waiting on crit gate round-trips, and Review's
  prose-plus-diff write-up duplicates what a direct diff read already
  shows. Default to a direct single-conversation loop (discuss → implement
  → run tests live → human reviews diffs in-editor and asks questions)
  unless the task is genuinely large/ambiguous or the human asks for the
  formal workflow. `crit <file>` is still a good tool standalone, on one
  file at a time, when in-chat review would get too dense.

## Suggested next steps — collections UI: CRUD done, search-in-collection next

Collections CRUD (#9) and the generic search partial (#10) are built and
committed. Nothing is half-finished in the working tree. Remaining work,
in order (keep the established loop: small task → run tests → human
reviews diff and asks questions → commit; explain Rails "why" as we go):

**Step 2.5 — browser (system) tests with Capybara — do this before step 3.**
Human wants automated browser coverage started early rather than
backfilled. Already in place: `capybara` + `selenium-webdriver` in the
Gemfile, `test/application_system_test_case.rb` (headless Chrome, Chrome is
installed), and an existing `test/system/user_workflow_test.rb` to copy
from. Run with `bin/rails test:system` (plain `bin/rails test` skips them).
Start with the things integration tests can't see: the collection Delete
`turbo_confirm` dialog (accept and dismiss), the search Turbo Frame
swapping results without a full page load, and one happy-path flow
(sign in → create → edit → delete a collection). Explain Capybara basics
(`visit`, `fill_in`, `click_on`, `accept_confirm`, `assert_text`) as we
go; keep it to a few tests, then add system coverage alongside each new UI
step (3, 4) instead of afterward.

**Step 3 — search on the collection page (add games to a collection).**
- Route: `resources :collections do resources :collection_games, only:
  %i[ create destroy ] end`; `CollectionGamesController` scoped through
  `Current.user.collections.find(params[:collection_id])`.
- `collections#show` gets `q` handling: runs `IgdbClient#search` and renders
  `games/search` with `url: collection_path(@collection)` and a new
  `collection_games/_add_result` action partial (per-result platform
  picker built from the result's `platforms` + an Add button posting
  `igdb_id` + `platform`).
- `collection_games#create`: `Game.find_or_refresh(igdb_id)`, then
  `@collection.collection_games.create(game:, platform:)`; the model
  already validates the platform against IGDB and uniqueness per
  `(collection, game, platform)` — surface those errors via flash.
- `collection_games#destroy` + a Remove button on the show page.
- Remember the `turbo_frame: "_top"` trick on any button inside the frame
  that redirects with a flash.

**Step 4 — live search-as-you-type.** Small Stimulus controller (importmap
already includes Stimulus) that debounces (~300ms) and submits the search
form into the existing `game-search` frame; add a minimum query length
(2–3 chars) server side to respect IGDB rate limits.

**Open items / decisions to revisit**
- `CollectionsController#destroy` and `CollectionGamesController#destroy`
  both call `destroy` and always report success. Fine today (no
  `before_destroy` callbacks, DB errors raise); add a failure branch (or
  `destroy!`) to **both** when a rule that can block deletion appears.
- Browser pass of collections CRUD + the search page frame (dev server:
  `bin/rails server`, needs Postgres: `brew services start
  postgresql@17`) was not yet done as of this update — check: nav link,
  create/edit/delete flows incl. the Delete confirm dialog, error box on
  blank/duplicate title, search results swapping without a full reload,
  Add on `/games/search` still showing its flash.
- `collection_flow_test.rb` is one file (~30 tests); consider reordering
  by action or splitting read vs. write if it keeps growing.
- Editor auto-format un-indented methods under `private` once; project
  convention (and Rails') is indented, rubocop allows both.
- Future ideas (see `.claude/PLAN.md` backlog): game details page
  (`games#show`) showing which collections a game is in; reusing
  `games/_search` elsewhere (e.g. a review form) via a different
  `action_partial`.
