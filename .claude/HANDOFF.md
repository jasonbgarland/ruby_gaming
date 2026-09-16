# Project handoff / status

Last updated: 2026-09-16 (after a multi-month gap since the last session,
which ended 2026-07-31)

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

## Suggested next steps — IGDB / Game concept plan is approved, ready to build

Decided: the site will use the IGDB.com API for game data, with a local
`Game` model caching what's needed, plus a future `Collection` model
(user has zero or more collections, e.g. "Owned"/"Wishlist"; a collection
has zero or more games) powering wishlist/backlog/now-playing/favorites.

`.claude/PLAN.md` has been through a full crit review (4 rounds, now
**approved**) and is ready to execute. It's split into 3 sequential
`/workflow` runs, each with a ready-to-paste prompt at the top of its
section:

1. **Run 1 — IGDB client + credentials.** Add `igdb.client_id`/
   `igdb.client_secret` to Rails encrypted credentials; build
   `app/services/igdb_client.rb` (Twitch OAuth token fetch/cache + a
   `search` method against IGDB's `/games` endpoint). Unit tests stub
   HTTP; a separate opt-in integration smoke test hits the real API.
2. **Run 2 — `Game` model.** One row per game (confirmed: IGDB's
   `igdb_id` is per-game, not per-platform), `platforms` as a native
   Postgres array column with a GIN index (for future platform search),
   24h on-read cache refresh. Migrating fields from a prior Python/
   SQLAlchemy version of this model — full reference kept in PLAN.md.
3. **Run 3 — Search page.** Live IGDB search box; selecting a result
   upserts a local `Game` row by `igdb_id` — just enough to prove the
   model/client work together, deliberately not "add to library" UX.

Run in order — run 3 depends on runs 1-2. Start the next session by
pasting Run 1's `/workflow` prompt (top of `.claude/PLAN.md`).

**Noted for later** (not yet a plan): platform-specific ownership (e.g.
"I own the Xbox copy of Hollow Knight") will live on the future
`Collection`↔`Game` join row, not on `Game` itself — captured in
PLAN.md's "Deferred: Collection / library concept" section so it isn't
lost before that story gets planned.
