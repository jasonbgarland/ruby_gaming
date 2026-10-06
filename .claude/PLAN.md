# Plan: Collection model

Status: **model layer built and tested (2026-09-24)** — migrations,
`Collection`/`CollectionGame` models, associations, and validations are
done; see `.claude/HANDOFF.md` for the committed result. This plan
covered **just the model layer**. **Update 2026-10-06:** the collections
CRUD UI and a generic search partial are now built (see "UI plan" below and
`.claude/HANDOFF.md` #9–10); search-inside-a-collection is the next step.

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

As built — see `app/models/collection.rb`, `app/models/collection_game.rb`,
`app/models/user.rb`, `app/models/game.rb` for the actual code (the
`CollectionGame` platform validator ended up as a private method that
refreshes the game from IGDB before checking membership — see "Decisions
made" below).

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
  `(collection_id, game_id)` — matched by a model-level
  `validates :game_id, uniqueness: { scope: [:collection_id, :platform] }`
  on `CollectionGame` for a friendly pre-save error, backed by the DB
  index as the race-condition-safe enforcement.
- **Title uniqueness**: scoped per user, not global — `validates :title,
  uniqueness: { scope: :user_id }` plus a matching DB-level unique index
  on `(user_id, title)`. Two different users can each have a "For Sale"
  collection; one user cannot have two.
- **Cascade deletes**: `dependent: :destroy` on both `User → Collection`
  and `Collection → CollectionGame`, so deleting a user or a collection
  cleans up orphaned rows automatically. `Game → CollectionGame` also
  gets `dependent: :destroy` (deleting a cached `Game` row — unlikely,
  but possible — shouldn't leave dangling join rows).
- **Process**: direct conversation, not the formal `/workflow` skill —
  same as Runs 2/3. The model design was already fully settled through
  discussion before any code was written, so what's left (migrations,
  validations, tests) was mechanical enough not to need the formal
  Plan→Design→Build→Review paper trail.
- **Platform validation against a stale/empty `game.platforms`**: the
  validator calls `Game.find_or_refresh(game.igdb_id)` before checking
  `platform` against the (now-fresh) `platforms` list, rather than
  validating against whatever's currently cached. Avoids spuriously
  rejecting a platform IGDB actually has just because the local `Game`
  row hadn't been refreshed in the last 24h.

## UI plan (decided 2026-10-06)

Decisions from the scoping conversation:

- **Collection is the home for search.** Users add games from a
  collection's show page; the standalone `/games/search` page stays as-is
  (bare `Game` upsert) for now.
- **Search is a generic partial**, not tied to collections (it may later be
  reused e.g. when writing a game review): `games/_search.html.erb` takes
  `url`, `query`, `results`, and an `action_partial` the caller supplies
  (rendered once per result). Chosen over a block/lambda or a bare form URL
  because it is plain Rails and easy to follow.
- **Turbo Frame first, debounce after.** End goal is live search-as-you-type;
  the partial wraps its form + results in a `game-search` Turbo Frame (built),
  and a Stimulus debounce controller is a later, separate step.
- **Small tasks, review + commit after each**, direct conversation (no
  `/workflow`).

Status:
1. Collections CRUD — **done** (`47499b4`…`d62f7a1`).
2. Generic search partial + Turbo Frame — **done** (`4da13ae`).
3. Search on the collection page: `collection_games#create`/`destroy`,
   per-result platform picker, Remove button — **next** (details in
   `.claude/HANDOFF.md`).
4. Stimulus debounce (live search) — after step 3.

## Explicitly out of scope for this plan

- Re-fetching IGDB's numeric platform `id` (see "Platform representation"
  above) — deferred, string-based for now.
- A friendly failure path for `CollectionsController#destroy` — deferred
  until a rule exists that can actually block deletion.

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
