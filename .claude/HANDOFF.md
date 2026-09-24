# Project handoff / status

Last updated: 2026-09-24

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
   this entry, for detail.** UI is explicitly not built yet (see
   "Suggested next steps" below).

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

## Suggested next steps — Collection model layer done; UI not started

The IGDB/Game plan (`.claude/plan_archives/igdb-game.md`, formerly
`PLAN.md`) is fully built — see "What's built" #1–7. Its follow-on, the
`Collection` model (#8 above), is also now built at the model layer:
`Collection`/`CollectionGame` models, migrations, associations,
validations, and tests are done and committed. Full design discussion,
decisions made, and remaining scope live in `.claude/PLAN.md`.

**What's NOT built yet for `Collection`** — this is the actual next
step:
- Any UI: a `collections` controller + views (index/show/create/destroy,
  and adding/removing a game+platform to/from a collection).
- Wiring the existing search page's "Add" button to target a
  `CollectionGame` (with a platform picker) instead of the current bare
  `Game` upsert — this is the natural moment collections stop being
  invisible plumbing and become something a user actually interacts
  with.

Start the next session by scoping the UI as its own conversation (or
`.claude/PLAN.md` addendum) — talk through routes/controller actions/
views before writing code, same pattern as the model discussion that's
already in `PLAN.md`. Given it's a full CRUD surface with real per-user
UX (not just a model), it's worth at least discussing whether this one
warrants the formal `/workflow` skill vs. another direct conversation —
not yet decided.

**If there's no specific work queued up** (nothing pending from the
human, nothing in progress here), read `.claude/PLAN.md`'s "Future ideas
backlog" section, summarize the items there, and propose one to scope
into a real plan next — don't just pick one and start building.
