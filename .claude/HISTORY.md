# Project history

What has been built, in order. Detail (design rationale, test counts,
verification) lives in git history — `git show <hash>` or `git log --oneline
-- <path>`. This is a short index, not a replacement for the commits.
Current status and next steps are in `.claude/HANDOFF.md`; the backlog is in
`.claude/PLAN.md`.

Note: all commit hashes here were remapped after a one-time history rewrite
on 2026-10-08 (item 15), before the first push.

Last updated: 2026-10-22

1. **Initial scaffold** (`960dbea`) — vanilla Rails 8 app, Docker/Kamal
   deploy config present but not configured for a real target yet.
2. **User accounts** (`d0f9580`) — sign up/login (username or
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
18. **Game details page** (`8b50d89`…`791e98d`) — `GET /games/:id`, where
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
19. **Richer IGDB details, part 1** (`f1daf40`…`c1f8e0d`, PR #19) — only
    static, factual IGDB data (crowd-sourced fields like ratings, franchises,
    time to beat and storyline are deliberately left out; the reasoning is in
    the `PLAN.md` backlog, "IGDB data principle"). `IgdbClient#find` asks for
    `DETAIL_FIELDS` (url, slug, game type, modes, themes, companies, ESRB and
    PEGI age ratings) while `#search` keeps its lean list. New `games` columns
    `igdb_url`, `slug`, `game_type`, `game_modes`, `themes`, `age_ratings`,
    saved by `Game.upsert_from_igdb`. The game page shows them and an
    "Game details sourced from IGDB" link under the panel. Companies are parsed
    by the client but not stored yet (part 2). 175 regular tests.
20. **Richer IGDB details, part 2: companies** (`4e913d3`, `a90c3e1`,
    `cfd487b`) — `companies` (unique on `lower(name)`) and a `game_companies`
    join with a `role` (developer or publisher; unique per game, company and
    role). Companies match by name, case-insensitively, because the client
    returns no IGDB company ids; a company that both develops and publishes a
    game gets two rows. `Game.upsert_from_igdb` saves the game and syncs its
    companies in one transaction (stale rows removed on refresh).
    `Game#company_names(role)` feeds "Developer:" and "Publisher:" lines in
    `games/_panel`. 185 regular tests. That finished the static-fields work, so the
    temporary `igdb-fields.md` was folded into the `PLAN.md` backlog and deleted. The finished-plan
    archives (`plan_archives/`) were deleted too, ahead of making the repo
    public; the rationale is in the commits and the items above.
21. **Demo seeds** (`b7d634a`, `1980bfd`, `b3611a1`) — `Game.find_or_refresh`
    now serves the stale cached row when IGDB fails (missing credentials,
    network or API errors) and still raises when nothing is cached; the client
    is built inside the method, because a default argument would raise where
    the `rescue` can't see it. `db/seeds.rb` is idempotent and needs no IGDB
    credentials: it loads `db/seeds/games.yml` (IGDB's top 100, fetched once
    in a single request) through `Game.upsert_from_igdb`, then creates the demo
    user (`demo@example.com`) and three collections (8, 4 and 5 games). It
    refuses to run in production, since the demo password is public (README).
    `bin/ci` runs it too. 193 regular tests.
22. **UI polish** (`1bbd6d1`, `19b85dd`, `d33820a`, `7895eb5`, `598e8b4`,
    `4f26c08`) — plain CSS, no framework: the palette is CSS variables in
    `application.css`, the container is 960px, and `.card`, `.chip`, `.badge`
    and button variants are shared. `GamesHelper#platform_label` shortens IGDB
    platform names ("PC (Microsoft Windows)" to "PC"; unlisted ones keep
    their full name) and is used by the game page, search rows and collection
    rows. `games/_panel` now has platform pills, a facts grid, chip groups for
    modes, themes and genres, age-rating badges, a type badge only when the
    game is not a "Main Game", and a long summary folded behind a native
    `<details>` (CSS `:has` hides the preview once it is open). At 640px and
    below the cover stacks above the details. The collection page has a
    header with Edit and Delete, platform chips and a quiet Remove; the nav
    wraps with a gap. Existing show-flow tests were rewritten as
    `assert_select`. 200 regular tests + 15 system tests. Follow-ups are in
    `PLAN.md`: site-wide polish, link back to the base game, undo a removal.
23. **Game page collections card** (`bec67fb`, PR #24) — the "Your
    collections" block on the game page (`games/_your_stuff`) is now a
    `.card`, with label headings, one row per entry (title link, platform chip,
    quiet Remove) and the add form on one wrapping row. Found in the manual
    browser pass; the rest of that pass needed no changes. The sign-in pages'
    missing theme and the default link colors went to the `PLAN.md` backlog.
24. **Portfolio README** (`260b20d`, `21a874d`, `7a66f28`, PR #25) — the
    README now opens with screenshots and a GIF (`docs/media/`), then why the
    project exists, what it demonstrates, how it was built, how to run it
    (live search needs a Twitch developer account and IGDB credentials; the
    seeded demo does not), what's next, and a LinkedIn contact. Screenshots are
    2x retina crops; Safari's Responsive Design Mode and the macOS screenshot
    tool gave full-page captures, so they were cropped with `sips` (note:
    `--cropOffset 0` centers the crop; use 1). The GIF was made from a
    screen recording with `ffmpeg` (800px wide, 12 fps, custom palette; 1.9 MB).
25. **Going public** (no code changes; docs only) — secrets re-check: only
    `config/credentials.yml.enc` and the stock `.kamal/secrets` template are
    tracked, no key, `.env` or `.pem` file has ever been committed on any
    branch, and a history grep found only variable names and docs. Clean-clone
    test in the scratchpad (databases renamed so the dev data stayed
    untouched): the README's credentials steps (`rm config/credentials.yml.enc`,
    then `bin/rails credentials:edit`) work, `bin/setup` seeds 100 games and
    the demo user, 200 tests + 15 system tests pass, and the server boots.
    CI was green on `main`. The repo was made public on 2026-10-23 and pinned
    on the GitHub profile, then branch protection was applied with the
    `PLAN.md` payload (five required CI jobs, up-to-date branches, linear
    history, no force-pushes or deletions, admins included).
