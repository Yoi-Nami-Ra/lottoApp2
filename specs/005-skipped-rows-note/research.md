# Research: Skipped Rows Note

No `NEEDS CLARIFICATION` items were left in the Technical Context. Each decision below was checked against the
code on `main` (`c88057c`).

## R1 — Where draws are checked against the game rules

- **Decision**: Check them in the shared fetch step of `RemoteSourcesManagerImp.live.sourceFor`, right after
  `module.fetchDraws()` returns, with a pure `FetchedDraws.validated(against: module.gameType)`. It builds a
  Domain `Combination` for each draw, the same way `SourcesRepoImpl.gameFor` reads stored draws. Draws that
  throw a `DomainError` are dropped and counted in a new `FetchedDraws.invalid` field. The parser's count stays
  in `skipped`.
- **Rationale**: This is the only place that knows both the fetched draws and the source's `GameType`.
  `RemoteSource` has no game type, and adding one would force a fake shape onto the "unsupported source"
  fallback, whose fetch throws anyway. Running the check once here covers every registered module, so no
  module can forget it. A pure function can also be tested without I/O.
- **Alternatives considered**:
  - *Check in `SourcesRepoImpl.fetchAndSaveDataFrom`*: this needs the game type there, through
    `RemoteSource.gameType` or a second `SourceRegistry` lookup keyed on the id. The first needs a fake shape
    for the fallback, and the second couples the sync path to the registry behind the injected manager.
    Rejected.
  - *Check inside `MBNetSource.fetchDraws`*: every future module would have to repeat it. Rejected.
  - *Check in `LocalStore.save`*: the store would learn game rules, and a skipped draw would be found only
    after it had been handed over to be saved. Rejected.

## R2 — When the whole response is unusable (FR-007)

- **Decision**: Move the "rows present, none usable" check from `MBNetSource.fetchDraws` into the same shared
  step, after validation. The rule is: `draws.isEmpty && (skipped + invalid) > 0` →
  `throw RemoteSourceError.unparseableBody(skipped: skipped + invalid)`. An empty body (0 rows) is still a
  successful empty history.
- **Rationale**: One rule covers both kinds of skip. It maps to the existing `.unreadableData` failure through
  `SyncFailure(classifying:)`, so spec 004 needs no new failure or copy.
- **Alternatives considered**: Keep the check in the module and add a second one after validation. That would
  split one rule into two places. Rejected.

## R3 — How the count is persisted (FR-004/005/006/013)

- **Decision**: `SourceMeta` gains `lastSyncSkipped: Int`. It is decoded with `decodeIfPresent … ?? 0`, so a
  `meta.json` written before this change still loads (FR-013). `LocalStore.save` gains a fourth argument,
  `_ skipped: Int`, which is written into the meta that the save derives. Only a successful save writes meta,
  so a failed or cancelled sync leaves the count unchanged (FR-006) with no extra code.
- **Rationale**: The meta is already the per-source "last successful sync" record, written atomically after
  the draws. The count belongs to the same record and follows the same lifetime rules.
- **Alternatives considered**:
  - *A separate `skipped.json`*: a second file can drift from the meta. Rejected.
  - *Folding the count into `contentDigest`*: the digest describes the stored draws, not the sync.
    Rejected.
  - *A default value on the closure*: Swift closures can't take default arguments. The ~15 existing
    `save(…)` call sites in tests get `, 0` added. This is mechanical.

## R4 — How the count reaches the card

- **Decision**: `Source.lastSyncSkipped: Int?` is `nil` until the first successful sync, like the other
  analytics. `SourceMeta.source(displayName:)` fills it in. `SourceEntry.State` gains `skippedInLastSync: Int?`,
  which is set by `sourceEntryState(now:)` and `apply(_:now:)` as the count only when it is > 0, and `nil`
  otherwise. The view shows the note when the value is non-nil.
- **Rationale**: The "is there a note" decision stays in the tested mapping (Principle II), and the view only
  checks for an optional. A failed sync never calls `apply`, so the note stays as it was (FR-006).
- **Alternatives considered**: Store the raw `Int?` and compare `> 0` in the view. That puts a decision in the
  view body. Rejected.

## R5 — Copy, plural wording, number grouping

- **Decision**: One token function in `SourceEntryView`:
  `LocalizedStringKey.skippedInLastSync(_ count: Int)`. It returns `"\(count.formatted()) record skipped in
  last sync"` when `count == 1` and `"\(count.formatted()) records skipped in last sync"` otherwise.
  `formatted()` applies the locale's grouping ("1,204").
- **Rationale**: The project has no String Catalog, and the rest of its copy is English tokens. An explicit
  `switch` is deterministic and easy to test. A `^[…](inflect: true)` automatic-agreement string depends on the
  Foundation morphology engine at render time, which a unit test can't observe.
- **Alternatives considered**: `inflect: true`; a `.stringsdict`. Either is the better route once the app is
  localised, but that is out of scope here.

## R6 — Look, placement, accessibility (FR-008/010/011)

- **Decision**: The note is a full-width `HStack` of `Image(.skippedWarning)`
  (`exclamationmark.triangle.fill`) and `Text`. It is placed between `headerRow` and `details` in the card's
  `VStack`. Foreground is `.warningYellow` for the icon and `.textPrimary` for the text, on a
  `.warningYellow.opacity(light/dark)` background with the same padding and corner tokens as the sync badge.
  The text has no `lineLimit`, so at AX sizes it wraps at word boundaries. The card keeps
  `.accessibilityElement(children: .contain)`, so VoiceOver reads the note as its own static text element, and
  the icon is `accessibilityHidden(true)`.
- **Rationale**: A full-width row needs no change to the existing header/details reflow (clarification
  2026-10-01). Pairing the icon with colour meets FR-011. Using the existing palette names keeps light and
  dark consistent.
- **Alternatives considered**: See the clarification options (bottom of the card, inside the badge).

## R7 — Logging (FR-012)

- **Decision**: The existing `Logger.sources.warning` in `fetchAndSaveDataFrom` logs `skipped` (unreadable
  rows) and `invalid` (rule-breaking draws) separately. `validated(against:)` stays pure and does not log.
- **Rationale**: Only the total reaches the user, and the split stays in the diagnostic log. Keeping the
  validation free of logging keeps it a plain function to test.
