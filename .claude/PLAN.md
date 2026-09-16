# Plan: Game concept via IGDB

Status: revised 2026-09-16 after crit round 1 — broken into 3 separate
workflow runs, to be executed in order.

## Goal

Introduce a local `Game` concept backed by IGDB (igdb.com) data, plus a
utility for querying IGDB, proven out with a simple search page. This is
the foundation for later features — a `Collection` concept (a user has
zero or more collections, each containing zero or more games; powers
wishlist/now-playing/backlog/favorites) — that are explicitly NOT in scope
here, just noted as the reason for some of the choices below.

## Workflow breakdown

Each run below is independent enough to plan/design/build/review on its
own via the `workflow` skill. Run in order — run 2 and 3 depend on run 1,
and run 3 depends on run 2. Copy the prompt under each into `/workflow`
when ready to start that run.

### Run 1 — IGDB client + credentials

```
/workflow Add IGDB API credentials to Rails encrypted credentials
(igdb.client_id / igdb.client_secret) and build an IgdbClient service
object (app/services/igdb_client.rb) that: (1) fetches and caches a Twitch
OAuth client-credentials access token (IGDB auth rides on Twitch OAuth;
tokens last ~60 days, so cache and don't re-fetch per request), and (2)
exposes a search(query) method using IGDB's Apicalypse query syntax
against the /games endpoint, returning normalized result data (igdb id,
name, cover image, summary, release date, platforms, genres). Cover with
unit tests that stub the HTTP layer (no real API calls in the normal
suite), plus a separate integration test that hits the real IGDB API as a
smoke test — tagged/gated so it does NOT run by default (e.g. skipped
unless an ENV flag is set), since it needs live credentials.
```

### Run 2 — `Game` model

```
/workflow Add a local Game model + migration to cache IGDB game data.
See .claude/PLAN.md "Game model" section for the field list and the open
schema question (one row per game vs. one row per game+platform) to
resolve during Design.
```

### Run 3 — Search page

```
/workflow Add a game search page: a controller/route (e.g. games#search)
with a search box that calls IgdbClient live and renders results (name,
cover, release date). Selecting a result upserts a local Game row keyed
by igdb_id (find_or_create), so we have real persisted data to verify the
model — this is NOT a "library" or "collection" feature, just enough
persistence to prove the model/client work together. Full save-to-library
UX is a future story once a Collection concept exists.
```

## Details behind each run

### 1. IGDB API credentials + client

- Add `igdb.client_id` / `igdb.client_secret` via
  `bin/rails credentials:edit`.
- For deploy later: `RAILS_MASTER_KEY` needs to reach the Kamal-deployed
  container via `.kamal/secrets` — not urgent for local dev.
- **Location convention resolved**: `app/services/igdb_client.rb`. Not an
  official Rails-core convention, but it's the de facto community
  standard for POROs wrapping an external API/integration, and with
  Zeitwerk, anything under `app/` autoloads for free — no reason to reach
  for top-level `lib/` (that's better reserved for code with no
  Rails/app dependencies at all, e.g. a gem-like extraction candidate).
- **Testing**: unit tests stub the HTTP layer (via `webmock`/`vcr` or
  similar — TBD in Design) so the normal suite never makes real network
  calls. Additionally, a real-endpoint integration smoke test, gated so
  it's opt-in (e.g. `RUN_IGDB_INTEGRATION=1 bin/rails test`) rather than
  part of the default `bin/rails test` run, since it needs live
  credentials and network access.

### 2. Local `Game` model

- Fields to start: `name`, `igdb_id`, `cover_image_id` (or full cover
  URL), `summary`, `first_release_date`.
- **Migrating from a prior Python/SQLAlchemy version of this model** —
  useful reference, reproduced here for Design to adapt rather than
  copy verbatim:
  ```python
  class Game(Base):
      __tablename__ = "games"
      id = Column(Integer, primary_key=True, index=True)
      igdb_id = Column(Integer, unique=True, nullable=True)
      name = Column(String, nullable=False, index=True)
      platform = Column(String, nullable=False, index=True)
      release_date = Column(Date, nullable=True)
      cover_url = Column(String, nullable=True)
      genre = Column(String, nullable=True)  # comma-separated
      __table_args__ = (UniqueConstraint("name", "platform", name="uq_name_platform"),)
  ```
- **Resolved**: IGDB's `games` endpoint gives one `id` per game entity,
  with `platforms` as an array field on that entity (a many-valued
  attribute, not a separate game per platform) — the same "Witcher 3"
  game id covers its PC/PS4/Xbox releases. So `igdb_id` unique-per-row is
  correct, and the Python model's per-(game, platform) row with
  `uq_name_platform` doesn't map onto IGDB's actual shape. Since platform
  search is a known future need, store `platforms` as a native Postgres
  array column (`platforms:string, array: true` with a GIN index) rather
  than jsonb — arrays support `platforms @> ARRAY['PC']`-style queries
  and index cleanly for that access pattern.
- Similarly, `genre` as comma-separated text was a SQLAlchemy pattern —
  Rails/Postgres has a native array/jsonb type that's a cleaner fit;
  Design should just pick one, no need to preserve the comma-separated
  convention.
- **Caching/staleness strategy**: IGDB game data changes rarely, so a
  long TTL is fine — recommend refreshing a local `Game` row if it's
  older than ~24h when it's next looked up (on-read refresh), rather than
  a background sync job. Design should confirm this is enough or whether
  a scheduled job is warranted later.
- Local `Game` rows are a cache, not a live mirror — created on demand
  (see run 3), not pre-synced in bulk.

### 3. Search page

- Calls `IgdbClient` live for the search box; no persistence required
  just to browse results. **This means every search query hits the real
  IGDB API, always** — the 24h cache/refresh window (see above) applies
  only to already-selected/persisted `Game` rows, not to browsing itself.
  There's no "cold cache stampede" concern here because search was never
  meant to be served from the local cache — it's inherently a live
  lookup, same as it would be on day 1000 as on day 1.
- Selecting a result upserts a local `Game` row by `igdb_id`
  (find_or_create) — just enough to validate the model end-to-end.
  Deliberately not framed as "add to library"; see below.

### Deferred: Collection / library concept

Raised in review: what does "adding" a game actually mean? Answer —
that's a future story once a `Collection` model exists (a user has zero
or more collections; a collection has zero or more games; this is what
wishlist/now-playing/backlog/favorites will be built from). Not part of
runs 1-3. The search page's upsert-on-select behavior is just plumbing to
prove the model works, not a stand-in for real collection UX.

**Design note to carry forward to that future story**: since `Game` is
one row per game with `platforms` as a list (not one row per platform —
see above), platform-specific ownership (e.g. "I own the Xbox copy of
Hollow Knight" in my "Owned" collection) doesn't belong on `Game` itself.
It belongs on the *join* between `Collection` and `Game` — e.g. a
`CollectionEntry` row with `game_id`, `collection_id`, and its own
`platform` column (one of the game's available platforms) for the
specific copy the user owns/wants. This keeps `Game` as a clean shared
cache while letting per-user, per-copy platform detail live where it
actually belongs. Not resolved further here — full design happens when
the Collection story is planned.

## Explicitly out of scope for this plan

- Collection / wishlist / now playing / backlog / favorites — future
  story once `Game` exists.
- Bulk-syncing or caching IGDB's full catalog locally.
- Any UI polish beyond basic readable styling (consistent with how the
  auth feature was scoped).

## Open questions still for Design (per-run)

- Run 1: exact stubbing library (webmock/vcr/other) for HTTP tests.
- Run 2: confirm 24h on-read refresh is sufficient vs. needing a
  scheduled sync job.
