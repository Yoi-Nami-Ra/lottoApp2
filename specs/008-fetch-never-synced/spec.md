# Feature Specification: Fetch Button on Never-Synced Sources

**Feature Branch**: `008-fetch-never-synced`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "LTA-3 — Show Fetch instead of Refresh on never-synced sources. Ticket description: Documentation.docc TODO item 003: a source that has never been fetched should signal it is not yet available to compute but can be fetched, with a \"Fetch\" button instead of \"Refresh\". Currently every card shows \"Refresh\" regardless of `lastSync`. Derive the label in the reducer from the source's sync state, add the copy token, and cover the never-synced state in previews (light/dark) and tests. Context from analysis: applies to both the full card (SourceEntryView, text label \"Refresh\"/\"Refreshing\") and the compact card (CompactSourceEntryView, icon-only with VoiceOver label \"Refresh\"/\"Refreshing\"); never-synced = `lastSync == nil` (`SyncSeverity.notSynced`); the fetch action itself (`refreshButtonTapped` → `blSources.fetchFrom`) is unchanged. Use spec number 008 (latest across local and remote branches is 007)."

## Clarifications

### Session 2026-10-01

- Q: Should a never-synced source also be marked as "not available to compute" outside its card (e.g. blocking chain runs), or does this feature only change the card's sync button? → A: Only the card's sync button; chain runs are unchanged (a run over a source with no draws already shows "No draws").
- Q: While a fetch is running, what should the button's icon be? → A: The existing spinning sync arrows; the fetch icon is the idle state only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A never-synced source offers to fetch its data (Priority: P1)

A person opens the app with a source that has never been downloaded. Its card already says "Not synced", but the button beside it says "Refresh", which suggests there is something to bring up to date. With this feature the button says "Fetch" instead, so the person can tell at a glance that this source has no data yet and that tapping the button is how they get it. Once the first sync succeeds, the card shows "Refresh" from then on.

**Why this priority**: This is the whole ticket. "Refresh" on a source with no data misdescribes both the source's state and what the button will do.

**Independent Test**: Show the start page with one never-synced source and one synced source; the never-synced card's button reads "Fetch" and the synced card's reads "Refresh". Tap Fetch, let the sync succeed, and the button reads "Refresh".

**Acceptance Scenarios**:

1. **Given** a source that has never synced, **When** its full card renders, **Then** the sync button is labelled "Fetch".
2. **Given** a source that has synced at least once, **When** its full card renders, **Then** the sync button is labelled "Refresh", as today.
3. **Given** a never-synced source, **When** the user taps Fetch, **Then** the same download runs as a refresh does today, and the button shows "Fetching…" while it runs.
4. **Given** a never-synced source whose fetch is running, **When** the fetch succeeds, **Then** the button changes to "Refresh".
5. **Given** a never-synced source whose fetch is running, **When** the fetch fails, **Then** the failure is reported as today and the button still says "Fetch", because the source still has no data.

---

### User Story 2 - The compact card makes the same distinction (Priority: P2)

On a narrow screen each source is a compact row whose sync button shows only an icon. A never-synced source's compact button must make the same Fetch-versus-Refresh distinction: visually through its icon, and by name for assistive technologies.

**Why this priority**: Narrow screens are the most common layout. Without this, the distinction only exists on wide screens and for sighted users. It builds on Story 1's rule for deciding Fetch versus Refresh.

**Independent Test**: Render a compact row for a never-synced source and one for a synced source. The icons differ, VoiceOver announces "Fetch" and "Refresh" respectively, and while syncing it announces "Fetching" and "Refreshing".

**Acceptance Scenarios**:

1. **Given** a never-synced source on a narrow screen, **When** its compact row renders, **Then** the sync button shows the fetch icon and is announced as "Fetch".
2. **Given** a synced source on a narrow screen, **When** its compact row renders, **Then** the sync button shows the refresh icon and is announced as "Refresh", as today.
3. **Given** a never-synced compact row, **When** its fetch is running, **Then** the button shows the spinning sync arrows, is dimmed and ignores taps as a refresh does today, and is announced as "Fetching".

---

### User Story 3 - Fetch reads well in every appearance (Priority: P3)

The Fetch button is legible in light and dark appearance and at every text size. On the full card, its label stays on one line without being cut off, just as "Refresh" does today.

**Why this priority**: The source cards were just reworked for large text sizes (spec 007). The new label must not regress that work. This is quality on top of Stories 1–2.

**Independent Test**: Previews of never-synced full and compact cards in light and dark, including the largest accessibility text size.

**Acceptance Scenarios**:

1. **Given** a never-synced source, **When** its card renders in light or dark appearance, **Then** the Fetch button uses the same colours, border and corners as the Refresh button.
2. **Given** the largest accessibility text size, **When** a never-synced full card renders, **Then** "Fetch" and "Fetching…" stay on one line without being truncated or broken mid-word.

### Edge Cases

- **First fetch fails**: the source still has no data, so the button keeps saying "Fetch". The error alert uses the existing per-failure wording, and the one general-purpose message says "Couldn't fetch <source>" instead of "Couldn't refresh <source>".
- **A fetch succeeds but stores 0 draws**: the source has now synced, so the card shows a last-sync time and "Refresh". The label follows whether a sync has succeeded, not how many records are stored.
- **A fetch is cancelled** (for example by a newer tap): the source's sync state does not change, so the label doesn't either.
- **The sources reload while a fetch is in progress**: the label follows the reloaded sync state, and the in-progress state is kept as it is today.
- **Selection and expansion**: tapping Fetch changes neither which source is selected nor whether a compact row is expanded, the same as Refresh today.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each source's sync action MUST be one of two kinds: **fetch** when the source has never synced successfully, **refresh** when it has. This kind MUST be decided by the source's own state, not by the view.
- **FR-002**: The kind MUST be re-decided whenever the source's state is loaded or updated, so it switches from fetch to refresh after the first successful sync, without a relaunch.
- **FR-003**: On the full card, the button MUST read "Fetch" when idle and "Fetching…" while running for the fetch kind, and "Refresh" / "Refreshing…" for the refresh kind, as today.
- **FR-004**: On the compact card, the icon-only button MUST use a fetch icon for the fetch kind when idle and the existing refresh icon for the refresh kind. It MUST be announced as "Fetch" / "Fetching" or "Refresh" / "Refreshing" respectively.
- **FR-005**: Fetch MUST start exactly the same sync as Refresh does today, with the same in-progress behaviour: dimmed, ignores repeat taps, and the spinning sync arrows. While any sync runs, on either card variant, the icon is the spinning sync arrows; the fetch icon is shown only while a fetch-kind button is idle.
- **FR-006**: A failed or cancelled first fetch MUST leave the kind as fetch.
- **FR-007**: The general-purpose sync-failure message MUST say "Couldn't fetch <source>. Try again." when the failed sync was a fetch, and keep "Couldn't refresh <source>. Try again." for a refresh. The per-failure messages are unchanged.
- **FR-008**: Every new piece of copy and every new icon MUST be a named design token, following the existing card tokens.
- **FR-009**: The Fetch button MUST keep the Refresh button's colours, border, corners and one-line label rules, in light and dark appearance and at every text size.
- **FR-010**: There MUST be previews of a never-synced full card and a never-synced compact card, idle and fetching, in light and dark appearance.

### Key Entities

- **Source sync action**: the kind of sync a source's button offers. It is **fetch** (never synced successfully) or **refresh** (synced at least once), derived from the source's last successful sync. It determines the button's label, icon, spoken name, in-progress label and general-failure wording. It is never stored.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of renders, a never-synced source's card offers "Fetch", and a source that has synced offers "Refresh", on both card variants.
- **SC-002**: After the first successful sync, the button reads "Refresh" with no further user action or relaunch.
- **SC-003**: A screen-reader user hears "Fetch" or "Refresh" on the compact card, and the right one each time, matching what the full card shows.
- **SC-004**: No regression on the source cards: every existing card behaviour (refreshing, failures, selection, expansion, the skipped-records note, large-text reflow) behaves exactly as before for synced sources.

## Assumptions

- "Never synced" means the source has no successful sync recorded. The cards already show this state as "Not synced", so no new source state is introduced.
- The fetch icon is a "download" style system symbol, distinct from the refresh arrows. The full card shows it next to "Fetch" in the same place the refresh icon sits beside "Refresh", and switches to the spinning sync arrows while fetching.
- The in-progress label for a fetch is "Fetching…" on the full card and "Fetching" in the compact card's spoken name, matching the Refresh/Refreshing pair.
- The approved card design (`design/final/source-cards.html`) only draws the Refresh state. The Fetch state reuses that design's button in every respect except its label and icon, so no separate design ticket is assumed.
- The sync itself, the order of sources, and what the "Not synced" text and sync badge show are all unchanged.
- **Out of scope**: anything outside the source card's sync button. Chains, blocks and their runs treat a never-synced source exactly as today.
