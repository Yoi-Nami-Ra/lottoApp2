# Research: Missing Records Estimate

No `NEEDS CLARIFICATION` items were left in the Technical Context. Each decision below was checked against the
code on `main` (`a3e462e`, after specs 007 and 008).

## R1 — Where the rules live

- **Decision**: Two pure Domain rules go in a new `Domain/BLogic/DrawCadence.swift`:
  - `DrawCadence.measure(drawDates: [Date], calendar: Calendar) -> DrawCadence?`, the window and "not enough
    history" rule (FR-001, FR-002);
  - `DrawCadence.missing(since latestRecord: Date, now: Date) -> Int`, the estimate (FR-004).

  The Data layer calls `measure` when it writes metadata. Presentation calls `missing` when it maps a `Source`
  into card state.
- **Rationale**: The window, the history rule and the formula are business rules about draws, so they belong
  in the Domain (Principle I), next to `Freshness`. Data and Presentation both depend inward on them, which
  the layering allows. Pure functions can be tested against hand-computed dates with no I/O.
- **Alternatives considered**:
  - *Compute in `LocalStore`*: the store would own a business rule, and the reducer would need a second copy of
    the formula. Rejected.
  - *Compute in the reducer*: the reducer doesn't have the draws, and reading them would mean a new
    dependency. Rejected.

## R2 — What is stored: a count, not a rate

- **Decision**: `DrawCadence` is a value type holding `drawsInWindow: Int` (≥ 1). `drawsPerDay` is computed as
  `drawsInWindow / 14`. The estimate is
  `floor(Double(drawsInWindow) × max(0, now − latest) / 1_209_600)`, where 1,209,600 is the number of seconds in 14 days.
- **Rationale**: Storing the rate as a `Double` and then multiplying loses exactness at the boundaries the
  tests pin. For example (6 ÷ 14) × 7 = 2.9999999999999996, whose floor is 2, while the spec says 3
  (US1-AS1). Keeping the integer count and dividing once gives exactly 3.0. The behaviour is the same as the
  ticket's formula, with no off-by-one from rounding.
- **Alternatives considered**: *Store a `Double` rate and floor with an epsilon*: the epsilon would be an
  arbitrary tolerance. Rejected.

## R3 — Window edges and the calendar

- **Decision**:
  - `Calendar.drawWeeks` is a Gregorian calendar with time zone UTC and `firstWeekday = 2` (Monday), defined in
    the Domain next to the rule.
  - With `L` = the latest draw date and `W0` = the start of the week containing `L`
    (`calendar.dateInterval(of: .weekOfYear, for: L)!.start`), the window is `[W0 − 14 days, W0)`: start
    included, end excluded.
  - "Not enough history" means `earliest draw > W0 − 14 days`, or no draw dates fall in the window.
  - The rule takes the calendar as a parameter, and tests pass `.drawWeeks` or a variant.
- **Rationale**: Draws are dated at midnight UTC (`MBNetParser.utcCalendar`), so the UTC weeks line up with draw
  days (clarification 2). A draw on the window's first Monday counts, and one on `W0` belongs to the latest
  week, not to the window. Fixing the calendar removes any dependence on the device's locale or time zone, and
  passing it as a parameter satisfies FR-010 without a new `DependencyKey`, because the rule is a pure
  function.
- **Alternatives considered**:
  - *`@Dependency(\.calendar)`*: it defaults to the user's calendar, which is the wrong one here, and it would
    put a dependency into a pure rule. Rejected.

## R4 — Computing at sync, persisting in metadata

- **Decision**:
  - `SourceMeta` gains `drawsInWindow: Int?`, read with `decodeIfPresent`, so older files decode as `nil`.
  - `LocalStore.meta(name:draws:asOf:skipped:)` sets it from `DrawCadence.measure(drawDates: merged.map(\.date),
    calendar: .drawWeeks)?.drawsInWindow`, so both `FileStore` and `MemoryStore` get it with no change to
    `save`'s signature.
  - `SourceMeta.source(displayName:)` lifts it into `Source.cadence: DrawCadence?`.
- **Rationale**: This is clarification 1. Listing stays a metadata-only read (SC-004). The cadence is taken
  over the merged, persisted set, as the record counts and dates already are (spec 001 FR-005). A failed sync
  never reaches `meta(…)`, so the stored cadence is unchanged (FR-003). This is the spec 005 pattern exactly.
- **Alternatives considered**: *Compute on every listing from `listDrawsFor`*: it reads about 7,400 draws on
  every page load. Rejected by the clarification.

## R5 — Severity and the estimate in `SourceEntry`

- **Decision**:
  - `SourceEntry.State` gains `missingEstimate: Int?`, which is `nil` when there is no estimate.
  - A new `SyncSeverity.init(source:now:)` uses:
    - `lastSync == nil` → `.notSynced`;
    - an estimate exists → 0 is `.low`, 1 is `.medium`, 2 or more is `.high`;
    - otherwise → the existing `init(lastSync:now:)`.
  - The estimate exists when `cadence != nil` and `latestRecord != nil`.
  - `sourceEntryState(now:)` and `apply(_:now:)` both set `missingEstimate` and `lastSyncSeverity` through one
    helper, so load and refresh can't drift apart (FR-009).
  - `now` is still `@Dependency(\.date)`, read by `StartPage` (Principle IV).
- **Rationale**: Severity is already stored state derived at mapping time from the injected clock (spec 001).
  The new rule slots into the same place, and the day-based rule stays exactly as it is for the fallback
  (SC-003).

## R6 — The "~N missing" line

- **Decision**:
  - `RecordDateDetail` (in `SourceCardParts`) gains an optional `missing: Int?`. When it is greater than 0,
    a `Text("~\(n.formatted()) missing")` appears under the date, in `.caption` and `textSecondary`, with an
    `exclamationmark.circle` icon that is hidden from VoiceOver. The badge already carries the severity colour,
    so the line stays neutral and needs no severity input.
  - The VoiceOver label is "about N missing".
  - `SourceEntryView` and `CompactSourceEntryView` pass `store.missingEstimate` for `.latest` only.
- **Rationale**: The line sits "next to Latest Record" on both cards from one shared part (spec 007 R4). The
  icon and the words carry the meaning without relying on colour (FR-008). Wrapping follows the existing
  date `Text` (no `lineLimit`).

## R7 — Testing strategy

- **Decision**:
  - New `lottoApp2Tests/Domain/DrawCadenceTests.swift`, with fixed UTC dates:
    - a full window (6 draws → 6);
    - the latest draw in the same week as the window end;
    - an empty window → `nil`;
    - history starting one day after the window start → `nil`;
    - history starting exactly at the window start → measured;
    - a draw on `W0` excluded;
    - missing = 0, 1 and many (6/7 days → 3), a negative interval → 0, and a large count;
    - `drawsPerDay`.
  - `LocalStoreTests`: `save` writes `drawsInWindow`, the value survives a store reload, and a legacy
    `meta.json` without it decodes as `nil`.
  - `SourceEntryTests`: severity from the estimate (0, 1, 2, 5), the fallback (no cadence, and no latest record),
    never synced, `missingEstimate` mapping, and `apply` recomputing.
  - `StartPageTests`: a refresh success recomputes the estimate and the severity from the injected clock.
- **Rationale**: This is Principle III, with every user-visible number pinned to a hand-computed value (SC-001).
