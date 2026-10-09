# Project history

What has been built, in order. Detail (design rationale, test counts,
verification) lives in git history — `git show <hash>` or `git log --oneline
-- <path>`. This is a short index, not a replacement for the commits.
Current status and next steps are in `.claude/HANDOFF.md`; the backlog is in
`.claude/PLAN.md`; finished plans (IGDB game, collections design and
decisions) are in `.claude/plan_archives/`.

Note: all commit hashes here were remapped after a one-time history rewrite
on 2026-10-08 (item 15), before the first push.

Last updated: 2026-10-09

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
4. **IGDB client + credentials** (`9d89326`, `b28b4ec`) —
   `app/services/igdb_client.rb`: Twitch OAuth client-credentials flow
   (cached token), `#search`/`#find` against IGDB's `/games`, returns
   `IgdbClient::Game` value objects. Real credentials in encrypted
   credentials; live smoke test: `RUN_IGDB_INTEGRATION=1 bin/rails test
   test/services/igdb_client_live_test.rb`.
5. **Postgres** (`cd48266`) — replaced SQLite for native array/GIN columns.
   Needs local Postgres (`brew services start postgresql@17`);
   `test/test_helper.rb` disables parallel test workers on macOS only
   (Homebrew Postgres isn't fork-safe).
6. **`Game` model** — `games` table (`igdb_id` unique, `platforms`/`genres`
   arrays, `refreshed_at`); `.find_or_refresh(igdb_id)` is the on-read
   refresh entry point (24h staleness).
7. **Standalone search page** — `GamesController#search`/`#create`
   (`/games/search`): live IGDB search; Add just upserts a bare `Game` with
   no user link (an iterative artifact kept to validate behavior; revisit).
8. **`Collection` / `CollectionGame` models** (`6a3e646`) — per-user
   collections; join model carries `platform`, validated against the
   game's IGDB platforms, unique per `(collection, game, platform)`.
9. **Collections CRUD UI** (`a4dc781`…`1db99d3`) — index/show/new/edit/
   destroy + nav link. `CollectionsController` scopes everything through
   `Current.user.collections` (other users' ids 404).
10. **Generic search partial** (`b72143d`) — `games/_search.html.erb`.
    Locals: `url`, `query`, `results`, `action_partial` (a partial rendered
    once per result with `result`/`query` locals — the caller's own action).
11. **System (browser) tests** (`4a03cce`) — Capybara + headless Chrome in
    `test/system/collections_test.rb`; `bin/rails test:system` (plain
    `bin/rails test` skips them). `README.md` lists dev commands.
12. **Add/remove games in a collection** (`9e996ff`, `09d4720`) — nested
    `collection_games` routes (create, destroy);
    `CollectionGamesController` loads the collection via
    `Current.user.collections`. The collection show page embeds the search
    partial with `collection_games/_add_result` (platform dropdown + Add);
    Remove button per row. Buttons inside the search frame use
    `turbo_frame: "_top"` so the redirect reloads the whole page and the
    flash shows.
13. **Live search-as-you-type** (`8725ac1`) — Stimulus `autosubmit`
    controller debounces (300ms) and auto-submits only from 3 characters
    (`data-autosubmit-min-length-value`); Enter/Search always searches.
    The search **form sits outside** the `game-search` Turbo Frame and
    targets it (`data-turbo-frame`), so a swap replaces only the results
    and the text box keeps focus. The 3-char rule is client-side only (the
    server has no minimum).
14. **More system tests + clearer duplicate error** (`f3a2536`, `339123b`,
    `a78af06`) — adding the same game on the same platform now reads "Game
    has already been added on that platform" (custom `message:` on the
    `CollectionGame` uniqueness validation). Five new system tests: duplicate
    add, same game on two platforms with one-at-a-time remove, duplicate
    collection title keeps typed input, search box keeps focus across live
    swaps, no-results search. Rule checks (authorization, bad platform) stay
    in the faster integration tests; system tests are for browser behavior.
15. **No Claude attribution; history rewrite** (`70c9359`) — removed the
    `Co-Authored-By: Claude` trailer from all earlier commits (tree contents
    unchanged, hashes changed) and set `attribution` to empty in
    `.claude/settings.json` so future commits and PRs carry none.
16. **GitHub + CI** (`25af0fc`, `4fed063`, `2d973ec`, `460415c`) — private
    repo `jasonbgarland/ruby_gaming`. Tests use fake IGDB credentials
    (`test_helper.rb`) so CI needs no `RAILS_MASTER_KEY`. The CI `test` and
    `system-test` jobs got a `postgres:17` service and `DB_*` env vars, plus
    a concurrency group. Updated `sqlite3` (audit advisory) and `brakeman`
    (its wrapper refuses to run unless latest). The git workflow (GitHub
    flow, rebase-and-merge) is written in `CLAUDE.md`.
17. **Dependabot tuning, rebase-only merges, search fix** (`a7400fd`,
    `2cdec8d`, `dd61ef1`) — Dependabot now checks monthly and groups minor/
    patch bumps (one PR per ecosystem; majors separate); the repo allows only
    "Rebase and merge". Updated Rails to 8.1.4, the GitHub Actions
    (checkout 7, cache 6, upload-artifact 6) and `image_processing` 2.2.
    Fixed a double search: submitting the search form now cancels the pending
    300ms auto-submit (`autosubmit#cancel`), which also removed a flaky
    system test on CI. 13 system tests now.
18. **Game details page** (`412c392`…`b170528`) — `GET /games/:id`, where
    `:id` is the **IGDB id** so a search result can link before the game is
    saved (`find_or_refresh` fills it in; bad or unknown ids 404). Stacked
    layout: `games/_panel` (the game: cover, release date, platforms, genres,
    summary; same for everyone) above `games/_your_stuff` (the user's ties:
    collections holding the game with Remove, plus an add-to-collection form
    with collection and platform dropdowns). Game names in search results and
    collection rows link to it. The form posts to a new top-level
    `POST /collection_games` (collection comes from the dropdown, not the
    URL); `from=game` makes `CollectionGamesController` redirect back to the
    game page instead of the collection. `sign_in_via_browser` moved into
    `ApplicationSystemTestCase`. 2 new system tests (15 total).
