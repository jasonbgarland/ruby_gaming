# Plan: Collection model

Status: model design agreed via direct conversation (2026-09-24), not yet
built. This plan currently covers **just the model layer** (migrations,
associations, validations) — the earlier "saving a game just caches it on
the backend, no real collection concept" gap is what this closes. UI/UX
for creating and managing collections is explicitly a follow-on, not yet
discussed (see "Explicitly out of scope" below).

## Goal

Give users real persisted collections (e.g. "Wishlist", "Owned", "For
Sale") that hold zero or more games, each tied to the specific platform
the user wants/owns it on. Replaces the current "search page upserts a
bare `Game` row" behavior (from `.claude/plan_archives/igdb-game.md`
Run 3) with an actual user-facing concept — right now selecting a search
result has no relationship to any user at all.

- A user has zero or more collections.
- A collection has zero or more games, each paired with a platform.
- The same game can appear more than once in one collection, at different
  platforms (e.g. "own on PS4" and "want on PC" both in "Wishlist").

## Model design

Three tables. `Game` is unchanged (from the archived plan); `Collection`
is new; `CollectionGame` is a new **join model** (not a bare
`has_and_belongs_to_many` join table) because the relationship itself
carries data — `platform` — that a plain two-FK join table has no room
for.

| Model | Table | Columns |
|---|---|---|
| `Collection` | `collections` | `id`, `user_id` (FK), `title` (string, required), `description` (text, optional), timestamps |
| `CollectionGame` | `collection_games` | `id`, `collection_id` (FK), `game_id` (FK), `platform` (string, required), timestamps |
| `Game` | `games` | *(no changes)* |

```ruby
class User < ApplicationRecord
  has_many :collections, dependent: :destroy
end

class Collection < ApplicationRecord
  belongs_to :user
  has_many :collection_games, dependent: :destroy
  has_many :games, through: :collection_games

  validates :title, presence: true, uniqueness: { scope: :user_id }
end

class CollectionGame < ApplicationRecord
  belongs_to :collection
  belongs_to :game

  validates :platform, presence: true
  # platform must be one of game.platforms (see "Platform" decision below)
end

class Game < ApplicationRecord
  has_many :collection_games, dependent: :destroy
  has_many :collections, through: :collection_games
end
```

### Decisions made (no longer open)

- **Platform representation**: `CollectionGame#platform` is a plain
  string, validated to be one of that row's `game.platforms` (the
  `Array<String>` `Game` already caches from IGDB's `platforms.name`
  field — see `.claude/plan_archives/igdb-game.md`). Considered instead
  fetching IGDB's numeric `platforms.id` and storing that, but rejected
  for now: IGDB's platform names come from a controlled taxonomy on
  IGDB's backend (consistent per game), so plain strings support
  searching/sorting by platform without an extra schema change. Revisit
  only if platform names ever prove inconsistent in practice.
- **Duplicate games per collection**: allowed, as long as the platform
  differs. Uniqueness index is `(collection_id, game_id, platform)`, not
  `(collection_id, game_id)`.
- **Title uniqueness**: scoped per user, not global — `validates :title,
  uniqueness: { scope: :user_id }` plus a matching DB-level unique index
  on `(user_id, title)`. Two different users can each have a "For Sale"
  collection; one user cannot have two.
- **Cascade deletes**: `dependent: :destroy` on both `User → Collection`
  and `Collection → CollectionGame`, so deleting a user or a collection
  cleans up orphaned rows automatically. `Game → CollectionGame` also
  gets `dependent: :destroy` (deleting a cached `Game` row — unlikely,
  but possible — shouldn't leave dangling join rows).

## Migrations needed

1. `create_collections`: `user_id` (FK, `null: false`, indexed), `title`
   (string, `null: false`), `description` (text, nullable). Unique index
   on `[:user_id, :title]`.
2. `create_collection_games`: `collection_id` (FK, `null: false`,
   indexed), `game_id` (FK, `null: false`, indexed), `platform` (string,
   `null: false`). Unique index on `[:collection_id, :game_id,
   :platform]`.

## Open questions still for Design

- Exact validation for "`platform` must be one of `game.platforms`" —
  custom validator on `CollectionGame`, presumably (`errors.add` if
  `platform` not in `game.platforms`). Need to confirm behavior if
  `game.platforms` is empty/stale at validation time (block, or allow and
  let the on-read refresh catch up later?).
- Whether `collections#index`/`#show`/etc. (the actual UI) is part of
  this same run or a separate follow-on run — not yet discussed with the
  human. Current lean, per the process notes below, is that this one
  (new model + join table + real per-user UX) is big enough to warrant
  its own Design pass before Build, possibly via the formal `/workflow`
  skill rather than a direct conversation — TBD when picking this up.

## Explicitly out of scope for this plan

- Any UI for creating/viewing/editing collections (`collections`
  controller/views) — not yet discussed.
- Wiring the existing search page's "Add" button to create/target a
  `CollectionGame` instead of a bare `Game` upsert — natural next step
  after this lands, but not part of this plan.
- Re-fetching IGDB's numeric platform `id` (see "Platform representation"
  above) — deferred, string-based for now.

## Future ideas backlog

Carried forward from `.claude/plan_archives/igdb-game.md` (minus the
`Collection` item, which is this plan). Not scheduled, not planned — just
one-line prompts to flesh out when ready.

- Game details page — a page for a single `Game` (probably
  `games#show`, `/games/:id`), since right now a selected search result
  only gets upserted with a flash confirmation, no page to actually view
  it. Natural pairing with this plan once `Collection` exists — a game
  details page could show/edit which collections a game belongs to.
- Live search-as-you-type on the search page (results update while
  typing, no explicit submit) instead of the current submit-and-reload
  form.
