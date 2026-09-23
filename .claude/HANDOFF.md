# Project handoff / status

Last updated: 2026-09-23

## What this project is

`ruby_gaming` — a Rails 8.1 app for a gaming website. So far it is
**scaffold + auth only**; no gaming-specific domain model (games, scores,
leaderboards, matches, etc.) exists yet.

## What's built

1. **Initial scaffold** (`960dbea`) — vanilla Rails 8 app, Docker/Kamal
   deploy config present but not configured for a real target yet.
2. **User accounts** (`d0f9580`) — built via the multi-agent
   Plan→Design→Build→Review workflow (see `.claude/workflow/20260731-144252/`
   for the full paper trail: plan.md, design.md, build-report.md, review.md,
   retro.md).
   - Sign up, log in/out (via username or email), settings (update name/
     username/email/password), password reset — all generated from Rails
     8's built-in `bin/rails generate authentication` generator, used
     mostly as-is.
   - `users` table: email_address, username (unique, case-insensitive),
     first_name, last_name, password_digest.
   - `sessions` table: DB-backed sessions (not just cookie-based), tracks
     ip_address/user_agent, permanent signed cookie so sessions survive
     browser restarts.
   - Basic generator-default rate limiting on login/password-reset
     attempts (~10 attempts / 3 min) is in place.
   - Root route (`home#show`) is a placeholder "welcome / under
     construction" page that adapts based on logged-in state.
3. **Claude Code project config** (`fb6dc29`) — `.claude/` settings,
   `CLAUDE.md` project instructions.
4. **IGDB client + credentials — Run 1 of 3** (`8589e19`, `411334b`) —
   built via the multi-agent `/workflow` skill (Plan→Design→Build→Review
   with human gates via crit); see
   `.claude/workflow/20260917-133340/` for the full paper trail.
   - `app/services/igdb_client.rb`: authenticates against Twitch's OAuth
     client-credentials endpoint, caches the token (injectable `cache:`,
     defaults to `Rails.cache`), exposes `#search(query, limit:)` against
     IGDB's `/games` endpoint via Apicalypse syntax, returns normalized
     `IgdbClient::Game` value objects (igdb_id, name, cover_image_id,
     cover_url, summary, release_date, platforms, genres).
   - `igdb.client_id`/`igdb.client_secret` are real, working credentials
     in encrypted credentials (`411334b`) — **verified against the live
     IGDB API**, not just unit-tested: `RUN_IGDB_INTEGRATION=1 bin/rails
     test test/services/igdb_client_live_test.rb` passes.
   - 20 unit tests (all HTTP stubbed via webmock) + the live smoke test
     above, gated off by default.
   - `Net::HTTP` usage is deliberately confined to two private methods
     (`#fetch_token!`, `#games_request`) so a future Faraday swap (if
     retry/backoff/instrumentation needs grow) stays contained.
5. **Primary database switched from SQLite to Postgres** (`251aed5`) —
   decided during Run 2 planning: SQLite has no native array/GIN-index
   column type, which Run 2's `Game.platforms`/`genres` columns need per
   `.claude/PLAN.md`. Solid Queue/Cache/Cable stay on SQLite
   (production-only, unaffected). Requires a local Postgres server
   running (`brew services start postgresql@17`) — see the commit
   message for exact setup and a macOS-only parallel-test-forking
   workaround in `test/test_helper.rb` (Homebrew's Postgres build isn't
   fork-safe with Rails' default parallel test workers; harmless/inert
   on Linux/CI).
6. **`Game` model — Run 2 of 3** — built as a direct conversation (no
   `/workflow`, per the process-change decision below).
   - `db/migrate/..._create_games.rb`: `games` table with `igdb_id`
     (unique), `name` (indexed), `cover_image_id`/`cover_url`, `summary`,
     `first_release_date`, `platforms`/`genres` as native Postgres string
     arrays with GIN indexes, and `refreshed_at` (tracks last IGDB sync,
     kept separate from `updated_at` so unrelated future writes don't
     confuse staleness checks).
   - `app/models/game.rb`: validates `igdb_id`/`name`; `#stale?` (24h
     `REFRESH_INTERVAL`); `.upsert_from_igdb` (find-or-create by
     `igdb_id`); `.find_or_refresh(igdb_id, client:)` — the on-read
     refresh entry point Run 3's search page will call.
   - Added `IgdbClient#find(igdb_id)` (a `where id = X` Apicalypse
     lookup) alongside the existing `#search` text search — needed once
     `find_or_refresh` required refetching one specific game by id,
     which `#search` (a text search) can't do reliably.
   - Tests: 12 new `Game` model tests + 4 new `IgdbClient#find` tests,
     using a small hand-rolled fake client for `Game`'s tests (Minitest 6
     split `Mock` into a separate gem this project doesn't have).

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

## Suggested next steps — Run 1 & 2 done, Run 3 (search page) is next

Decided: the site will use the IGDB.com API for game data, with a local
`Game` model caching what's needed, plus a future `Collection` model
(user has zero or more collections, e.g. "Owned"/"Wishlist"; a collection
has zero or more games) powering wishlist/backlog/now-playing/favorites.

`.claude/PLAN.md` has been through a full crit review (4 rounds,
**approved**) and is split into 3 sequential runs:

1. **Run 1 — IGDB client + credentials. ✅ Done** (`8589e19`, `411334b`;
   see "What's built" above). Built via `/workflow`.
2. **Run 2 — `Game` model. ✅ Done** (see "What's built" #6 above). One
   row per game (confirmed: IGDB's `igdb_id` is per-game, not
   per-platform), `platforms`/`genres` as native Postgres array columns
   with GIN indexes, 24h on-read cache refresh via `Game.find_or_refresh`.
3. **Run 3 — Search page. Next up.** Live IGDB search box; selecting a
   result upserts a local `Game` row by `igdb_id` — just enough to prove
   the model/client work together, deliberately not "add to library" UX.

**Process change for Run 2 (human preference, decided 2026-09-17):** do
**not** use the formal `/workflow` skill (Plan→Design→Build→Review with
crit document gates) for this run. After using it for Run 1, the human
found it slow relative to its value for a well-scoped, single-deliverable
task — too much waiting on crit round-trips, and the Review phase's
prose-plus-diff write-up ends up restating the code you could just read
directly in a diff. Instead, run Run 2 as a single ongoing conversation:
talk through the approach briefly, implement directly, run
tests/migrations live, let the human review diffs and ask questions
in-editor (VS Code) as you go, and iterate — no separate plan.md/
design.md/review.md documents. If a specific file ends up with enough
back-and-forth comments to be unwieldy in chat, use `crit <file>` on
just that one file rather than the full multi-document workflow. Reserve
the formal `/workflow` skill for bigger or more ambiguous work where the
paper trail itself has lasting value (e.g. this HANDOFF's own multi-month
gap is exactly the scenario where Run 1's approach paid for itself).

Start the next session by picking up Run 3 (search page) directly in
conversation (no `/workflow` prompt needed) — see PLAN.md's "Search
page" section for the intended controller/route shape and the
find-or-create-by-`igdb_id` upsert behavior.

**Noted for later** (not yet a plan): platform-specific ownership (e.g.
"I own the Xbox copy of Hollow Knight") will live on the future
`Collection`↔`Game` join row, not on `Game` itself — captured in
PLAN.md's "Deferred: Collection / library concept" section so it isn't
lost before that story gets planned.
