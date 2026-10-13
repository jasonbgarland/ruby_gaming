# IGDB fields we could add

> Temporary working doc. Delete when Stories A–D are done (or folded into
> `HISTORY.md`) so `.claude/` doesn't accumulate stale docs.

Currently fetched from `/games`: `id`, `name`, `summary`, `first_release_date`,
`cover.image_id`, `platforms.name`, `genres.name`.

Based on knowledge of IGDB's API, not yet checked against live responses.

## Easy: extra fields in `SEARCH_FIELDS`, no extra endpoint

| Field | What you get | Storage |
|---|---|---|
| `storyline` | Longer blurb, often a rewrite of the summary (dropped; see Decisions) | `text` column |
| `total_rating`, `total_rating_count` | Combined user and critic score (0–100) and vote count | float and integer columns |
| `rating`, `aggregated_rating` (and counts) | IGDB user score and critic score, separately | float and integer columns |
| `slug`, `url` | Link back to the game's IGDB page (attribution) | string columns |
| `game_modes.name` | Single player, Multiplayer, Co-op | string array |
| `themes.name` | Fantasy, Horror, Sci-fi | string array |
| `player_perspectives.name` | First person, Third person, Isometric | string array |
| `keywords.name` | Free-form tags | string array |
| `franchises.name`, `collection.name` | Franchise and series | string or array |
| `game_type.type` | Main game, DLC, expansion, remake (old `category` is deprecated) | string |
| `status` | Released, alpha, beta, cancelled | string |
| `age_ratings` | ESRB and PEGI ratings | needs expanded sub-fields |

## Medium: nested objects, probably a new table

| Field | What you get |
|---|---|
| `involved_companies.company.name` + `developer`/`publisher` flags | Who made and published it (many-to-many, likely a `companies` table) |
| `screenshots.image_id` | Images, built into URLs like the cover |
| `artworks.image_id` | Promotional art, good for banners |
| `videos.video_id`, `videos.name` | YouTube trailer ids, embeddable |
| `release_dates` | Per-platform and per-region dates |
| `websites` | Official site, Steam, GOG, Wikipedia |
| `external_games` | Ids on Steam, GOG and others |

## Relationship-based

- `similar_games`: "you might also like", linking to other game pages.
- `dlcs`, `expansions`, `parent_game`, `remakes`, `remasters`, `bundles`: related releases.
- `language_supports`: supported languages.
- `game_engine`: engine used.

## Other endpoints

- `/popularity_primitives`: popularity metrics, for a "trending" list.
- `/time_to_beats`: hours to beat (hastily / normally / completely).

## Suggested shortlist

1. Developer/publisher and `total_rating`.
2. Screenshots and a trailer.
3. `game_modes`, `themes`, `player_perspectives` (cheap, reuse array columns, enable filtering).
4. `time_to_beats` (separate endpoint).
5. `similar_games` (discovery, probably its own story).

## Decisions (from review, 2026-10-13)

**Principle (2026-10-13):** only pull IGDB data that is static and factual, not
crowd-sourced. Much of IGDB's community data (ratings, franchises, collections,
time to beat) is thin because few people edit it, so the site should own that kind
of data itself (reviews, ratings, tags, play status). What makes the site special
and what we keep ourselves vs. rely on IGDB for is still to be decided.

**Story A: static factual fields (one or more migrations, wider `find` list)**
- `url` (and `slug`) for an attribution line on the game page: "Game details
  sourced from IGDB" linking to the game's IGDB page.
- `game_modes`, `themes`, `game_type`.
- `storyline` **dropped**: community-edited free text; for The Quarry it was
  a longer rewrite of the summary, so it added nothing.
- Developer/publisher: `involved_companies.company.name` with the `developer` and
  `publisher` flags.
- Age ratings: `age_ratings.organization.name` +
  `age_ratings.rating_category.rating` (ESRB, PEGI, CERO, USK, ...).
- Split `search` (lean fields) from `find` (full fields).
- **Dropped:** IGDB user and critic ratings and counts, franchises, collections
  (probed live: franchise data was accurate for major games, but it is
  crowd-edited, and collections mix series with game-specific groups).
- `keywords`: **deferred.** IGDB has its own keyword list, but tagging is meant
  to be a signature feature, so investigate it in detail first (IGDB keywords vs
  our own user tags). Tracked in `.claude/PLAN.md` backlog.

**Story B: `time_to_beats`: dropped** (crowd-sourced, same principle). Kept below
for reference only. The endpoint is actually `/game_time_to_beats`
(fields `hastily`, `normally`, `completely` in seconds, plus `count`). Needs a
second request per game; check live data first. Include the full breakdown
(hastily / normally / completely), not just one number.

**Display (ongoing):** group the fields logically (e.g. ratings, play style, time
to beat, series) so the panel looks attractive and not overwhelming. Tweak over
time, part of the UI polish pass.

**Story C: screenshots and trailer.** Images are not downloaded: IGDB returns an
`image_id`, we build a CDN URL from it (like the cover). Trailers return a YouTube
`video_id`, embedded with an iframe. Separate task after Story A.

**Story D: discovery/curation (`similar_games` and more).** Its own story.

## Notes

- Fields added to `SEARCH_FIELDS` also go out with the search query. Consider a lean list for `search` and the full list for `find`. The field list is only what we *fetch*; filtering by other fields would go in the query's `where` clause, which can be added as needed (a query builder later if it grows).
- IGDB's terms require attribution; the `url` field helps.
