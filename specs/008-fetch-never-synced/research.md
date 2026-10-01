# Research: Fetch Button on Never-Synced Sources

## R1 — Where the Fetch-or-Refresh choice lives

- **Decision**: a computed `SourceEntry.State.syncAction: SyncAction`, which is `.fetch` when `lastSync == nil` and `.refresh` otherwise.
- **Rationale**: the ticket asks for it in the reducer layer (Principle II), not the view. Unlike `lastSyncSeverity`, which needs the injected clock and is therefore stored, this depends only on `lastSync`. A computed property can't drift from `lastSync`, so FR-002 (switching to Refresh after the first sync) holds through the existing `apply(_:now:)`, with no new write site. `State` stays `Equatable` with no extra stored field.
- **Alternatives**: a stored field set in `sourceEntryState` and `apply`. Rejected: it is a second source of truth that both writers must keep in sync. Deciding in each view: rejected, because it is branching in a view (Principle II) and would be duplicated across both card variants.

## R2 — Icons

- **Decision**: while idle, a fetch-kind button shows a download glyph, `arrow.down.circle`, as a new `ImageType` token. A refresh-kind button keeps `arrow.trianglehead.2.clockwise.rotate.90`. While any sync runs, both kinds show the spinning sync arrows (Clarification Q2). `RefreshIcon` becomes `SyncIcon(action:isSyncing:)` in `SourceCardParts`, shared by both cards.
- **Rationale**: the compact button is icon-only, so the distinction has to be visible there (FR-004). Spinning is the app's established "sync in progress" signal.
- **Alternatives**: keeping the refresh arrows for Fetch and changing only the text. Rejected: there would be no visual difference on compact. `icloud.and.arrow.down`: rejected, because there is no cloud account involved, which the glyph would wrongly suggest.

## R3 — Failure wording

- **Decision**: `AlertState.syncFailed(_:sourceName:action:)`. Only the general-purpose fallback (`.unknown`, `.cancelled`) varies: "Couldn't fetch \(name). Try again." versus "Couldn't refresh \(name). Try again." `StartPage` passes the entry's current `syncAction`. A failure doesn't change `lastSync`, so that is the kind the user tapped.
- **Alternatives**: a default `action: .refresh` argument. Rejected: a missed call site would silently fall back to the refresh wording. The parameter is required, and the three existing test call sites are updated.

## R4 — Copy

| Use | Fetch | Refresh (unchanged) |
| --- | --- | --- |
| Full card label | "Fetch" | "Refresh" |
| Full card while syncing | "Fetching…" | "Refreshing…" |
| Compact VoiceOver | "Fetch" | "Refresh" |
| Compact VoiceOver while syncing | "Fetching" | "Refreshing" |

"Fetch" and "Fetching…" are no longer than the Refresh pair, so spec 007's one-line label and scale-floor rules cover them without new metrics.

## R5 — Design coverage

`design/final/source-cards.html` draws only Refresh. Fetch reuses that button unchanged except for the label and the idle glyph. This is recorded as a deviation in the plan and quickstart rather than as a new design ticket (spec Assumptions).
