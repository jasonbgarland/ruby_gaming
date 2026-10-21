# Plan / backlog

What's built is indexed in `.claude/HISTORY.md` (design rationale lives in the
commits); current status and next steps are in `.claude/HANDOFF.md`.

## In flight: Sprint 1, demo-ready (week of 2026-10-20)

Goal: a reviewer can watch a 2-3 minute video, read a real README and look at
a public repo. About 15 hours; if it slips, cut scope. One branch and PR each:

1. `companies` — developer/publisher (done, merged).
2. `demo-seeds` — (code done; PR pending) idempotent `db:seed`: a demo user and a few populated
   collections from static game data, so seeding needs no IGDB credentials.
   Fail-soft refresh: with no IGDB credentials, a stale game is served from
   the cache instead of raising. Document the demo login in the README.
3. `ui-polish` — chips for themes and modes, age-rating badges, larger cover,
   styled collection and search pages; keep the partial-page refresh behavior.
4. `readme` — portfolio README, 3-4 screenshots, short demo-video steps.
5. `pre-public` — secrets re-check, CI green, then the repo goes public.

Cut order if time runs short: offline mode (stretch), restyling the collection
and search pages, age-rating badges.

Decisions: no LICENSE file (all rights reserved); `.claude/` stays public; no
hosting yet (local demo and video only). Stretch: an `IGDB_OFFLINE=1` mode
where search queries the local `games` table, as a safety net for live demos.

## Backlog

One-line prompts to flesh out when ready; not scheduled.

- **Screenshots and trailer** — IGDB gives an `image_id` for screenshots and
  artworks (build CDN URLs like the cover; nothing is downloaded) and a YouTube
  `video_id` for trailers (iframe embed). Needs wider `find` fields, storage,
  and a game-page section.
- **Discovery** — `similar_games` ("you might also like", linking to other
  game pages) and related releases (DLCs, remasters). Its own story.
- **Link back to the base game** — when a game page is not a Main Game (DLC,
  expansion, episode, mod, ...), link to its parent game. IGDB has
  `parent_game` (and `version_parent` for remasters/editions); both are static
  and factual, so they fit the data principle. Needs the wider `find` fields,
  a place to store the parent's `igdb_id` (a column on `games`), the link on
  the type badge shown by the game page (ui-polish adds the badge, with no
  hint text yet), and care for a parent not yet cached (link by `igdb_id`;
  the game page already fetches on demand). Decide the badge wording for
  add-ons ("needs the base game") versus variants (remake, port, standalone
  expansion) once real data shows the types in use.
- **IGDB data principle** — pull only static, factual IGDB data. Crowd-sourced
  fields (ratings, franchises, collections, time to beat, storyline) were
  probed and dropped; the site should own that kind of data itself (reviews,
  ratings, tags, play status). Other static fields IGDB offers if ever wanted:
  `player_perspectives`, `release_dates`, `websites`, `external_games`,
  `language_supports`, `game_engine`.
- **Tags / keywords** — a signature feature to investigate in detail before
  building: IGDB's own `keywords` list vs. our own user-defined tags (and how
  they combine).
- **Chore: rename `full_row` to `search_row`** in
  `test/services/igdb_client_test.rb`. It is the search-shaped fixture; the
  fuller one is now `detail_row`. Own tiny commit, after the richer-details work.
- **UI polish pass** — collection show/search markup is unstyled (platform
  picker beside Add, etc.). Needed before making the repo public. Do it after
  the richer-details stories and the product-direction discussion, on the whole
  game page at once. Game page ideas: platform icons (own mapping from IGDB
  platform names, text fallback, check icon licensing); chips for themes and
  modes; age-rating badges; group into facts / play style / about blocks; a
  larger cover or artwork banner; fold a very long summary.
- **Reuse `games/_search`** elsewhere (e.g. a review form) via a different
  `action_partial`.
- **Auth hardening** — the Rails 8 authentication generator already throttles
  login and password-reset attempts (about 10 per 3 minutes via `rate_limit`).
  Not built: configurable thresholds, account lockout after repeated failures,
  CAPTCHA-style challenges, IP-based throttling, or persistent (non-cache-store)
  rate-limit tracking. Email verification of a user's address is also not
  built and needs its own design pass (the generator doesn't provide it).

## Before making the GitHub repo public

- A real `README.md` (what it is, screenshots, how to run it).
- LICENSE: decided, none (all rights reserved), so the code stays free to
  commercialize.
- The UI polish pass above.
- `.claude/` (handoff, plans, workflow retros) stays public: decided.
- Secrets re-check: only `config/credentials.yml.enc` tracked, no
  `master.key` or `.env` anywhere in history.
- CI green on `main`.
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
