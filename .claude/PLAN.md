# Plan / backlog

What's built is indexed in `.claude/HISTORY.md` (design rationale lives in the
commits); current status and next steps are in `.claude/HANDOFF.md`.

## Sprint 1, demo-ready (week of 2026-10-20) — complete

A reviewer can watch a 2-3 minute video, read a real README and look at a
public repo. Shipped as HISTORY items 20-25 (companies, demo seeds, ui-polish,
README, going public).

Decisions: no LICENSE file (all rights reserved); `.claude/` stays public; no
hosting yet (local demo and video only). Stretch, never built: an
`IGDB_OFFLINE=1` mode where search queries the local `games` table, as a safety
net for live demos.

## Sprint 2, social: ratings and reviews (week of 2026-11-02)

Direction (decided in review, 2026-11-02): a **social** games site; ratings and
reviews are this iteration's signature feature. Social features arrive as
individual slices; a follow/friends feed comes after enough slices exist. One
branch and PR each, in order (realistically this week fits 1 and 2):

1. `ratings` — done (HISTORY item 26).
2. `reviews` — three PRs (decided 2026-11-02), one review per user per game,
   any game (no collection needed), text only, no HTML:
   - `reviews` — done (HISTORY item 27).
   - `review-spoilers` — done (HISTORY item 28).
   - `review-reports` (decided 2026-11-04): a report is a reason from a fixed
     list (spam, abusive, spoiler not hidden, other); one report per user per
     review (unique index + validation; button becomes "Reported"). No
     auto-hide: an admin decides. Hidden reviews are removed from lists for
     everyone except admins. `users.admin` boolean, set from console/seeds
     only. Small admin page: reported reviews with Hide/Restore and Dismiss.
     Civility notice on the review form beside the spoiler hint. Commits:
     (1) plan + handoff, (2) `reports` table, `reviews.hidden`, `users.admin`
     and `Report` model, (3) filter hidden reviews, (4) Report button +
     civility notice, (5) admin page, (6) docs.
3. `now-playing` — up to 3 games per user, cover squares on the profile; a 4th
   is refused with a nudge to finish one; no collection required; the game
   page shows how many people are playing it.
4. `profiles` — public profile showing now-playing, ratings and reviews.
5. Image uploads for long-review screenshots, then theme and UI polish. Uploads
   need Active Storage and `gem "ruby-vips"` added explicitly: `image_processing`
   2.x (updated 2026-10-08) no longer pulls in an image backend, and CI already
   installs `libvips`. Until then the `image_processing` gem could be dropped.

Visibility: ratings and reviews are public. Collections and Now Playing get a
privacy setting (public / friends only / private); v1 ships public + private
and stores the setting so friends-only slots in later.

Provisional defaults (approved 2026-11-02): new accounts default to public;
short reviews cap at 280 characters; moderation is an `admin` boolean on users
plus the `hidden` flag.

## Backlog

One-line prompts to flesh out when ready; not scheduled.

- **Social follow-ups** — comments and likes on reviews; upvoting reviews and a
  "top 3 reviews" block on the game page (the place to feature long reviews,
  which today only appear on the all-reviews page); follows, friends and an activity
  feed (after the individual slices); friends-only visibility.
- **Play history** — dates and hours played. Works best with platform API
  integrations, but many platforms have no public API; needs its own design
  thinking.
- **Screenshots and trailer** — IGDB gives an `image_id` for screenshots and
  artworks (build CDN URLs like the cover; nothing is downloaded) and a YouTube
  `video_id` for trailers (iframe embed). Needs wider `find` fields, storage,
  and a game-page section.
- **Discovery** — `similar_games` ("you might also like", linking to other
  game pages) and related releases (DLCs, remasters). Its own story.
- **Link back to the base game** — when a game page is not a Main Game (DLC,
  expansion, episode, mod, ...), link to its parent game via IGDB's static
  `parent_game` (and `version_parent` for remasters/editions). Needs the wider
  `find` fields, a parent `igdb_id` column on `games`, the link on the game
  page's type badge, and care for a parent not yet cached (link by `igdb_id`;
  the page fetches on demand). Decide badge wording for add-ons ("needs the
  base game"; IGDB names one type "Pack / Addon") versus variants (remake,
  port, standalone expansion) once real data shows the types in use.
- **IGDB data principle** — pull only static, factual IGDB data. Crowd-sourced
  fields (ratings, franchises, collections, time to beat, storyline) were
  probed and dropped; the site should own that kind of data itself (reviews,
  ratings, tags, play status). Other static fields IGDB offers if ever wanted:
  `player_perspectives`, `release_dates`, `websites`, `external_games`,
  `language_supports`, `game_engine`.
- **Tags / keywords** — a signature feature to investigate in detail before
  building: IGDB's own `keywords` list vs. our own user-defined tags (and how
  they combine). Deferred to its own sprint.
- **Chore: rename `full_row` to `search_row`** in
  `test/services/igdb_client_test.rb`. It is the search-shaped fixture; the
  fuller one is now `detail_row`. Own tiny commit.
- **Site-wide UI polish** — follow-up to the Sprint 1 `ui-polish` story, which
  covered the game page (including its collections card), collection show page
  and search results. Still plain: the collections index, an overall theme and
  color scheme (sign-in and sign-up have none), the default blue/purple link
  colors on collection and search titles, the collection and settings forms,
  login/registration/password pages (could use a narrow container), the home
  page and the nav. Also game page ideas: platform icons (own mapping from IGDB
  platform names, text fallback, check icon licensing). Reuse the `.card`,
  `.chip` and `.badge` styles and the CSS variables from `ui-polish`; add a
  phone-width check for each page.
- **Tech debt: split `application.css`** — about 700 lines in one file and
  growing (reviews added another section). Propshaft has no `@import`
  bundling, so split into a few files (e.g. `base.css` with the `:root`
  variables, `game.css`, `rating.css`, `reviews.css`) and change the layout's
  `stylesheet_link_tag "application"` to `:app`, which links every file under
  `app/assets/stylesheets` (the layout comment already claims this). Care
  needed: load order (variables first) and cascade order between files. A good
  light-day or tech-debt-day story, ideally paired with the theme pass above;
  check every page afterward, phone width included.
- **Undo a removal** (much later) — Remove on a collection entry deletes at
  once and only shows a "Removed ..." flash. Add an Undo on that flash. Decide
  first: re-create the row from the flash's data, or soft-delete (a
  `removed_at` column) so Undo is a true restore. Applies to every Remove
  button (collection page and the game page's collections card); deleting a
  whole collection already asks for confirmation.
- **Reuse `games/_search`** elsewhere (e.g. a now-playing game picker) via a different
  `action_partial`.
- **Auth hardening** — the Rails 8 authentication generator already throttles
  login and password-reset attempts (about 10 per 3 minutes via `rate_limit`).
  Not built: configurable thresholds, account lockout after repeated failures,
  CAPTCHA-style challenges, IP-based throttling, or persistent (non-cache-store)
  rate-limit tracking. Email verification of a user's address is also not
  built and needs its own design pass (the generator doesn't provide it).

## Branch protection for `main`

Enabled 2026-10-23 (free on public repos; a private free repo returned 403
"Upgrade to GitHub Pro" on 2026-10-08). Applied with
`gh api -X PUT repos/jasonbgarland/ruby_gaming/branches/main/protection --input <file>`;
to change it, re-run the same call with an edited file:

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
