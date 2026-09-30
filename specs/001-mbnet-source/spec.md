# Feature Specification: Real MBNet Server Source

**Feature Branch**: `001-mbnet-source`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "add real source for MBNet Server"

## Clarifications

### Session 2026-07-29

- Q: In what order should the MBNet draw list be displayed? → A: Displaying a list of fetched draw records is out of scope for this change — records are fetched, parsed, and stored, but not surfaced as a list view.
- Q: How does the user open MBNet's draw list from the sources screen? → A: No draw-list screen is added; a source can still be selected and synced as it is today.
- Q: On re-sync, how should stored draws reconcile with the freshly fetched full history? → A: Additive union — never delete a locally stored draw; only add new draws or update existing ones (identified by ordinal index).
- Q: What uniquely identifies a draw for de-duplication? (data-derived) → A: The ordinal index. Draw dates are NOT unique (6,424 distinct dates across 7,380 rows), so date alone cannot identify a draw.
- Q: What did "numbers shown in the UI" refer to? → A: The source-card **analytics/metadata** (record count, last sync time, earliest/latest record dates) — these MUST update on the card after each fetch/refresh. The individual draws' six numbers are stored but NOT displayed.

### Session 2026-07-30

- Q: When a refresh fails, how is the failure surfaced to the user? → A: An **alert dialog** is presented describing the failure; the user dismisses it. The card's analytics remain unchanged.
- Q: How should the "within a few seconds" performance target be made measurable? → A: Bound the on-device work only — parsing + persisting the full history (~7,400 records) completes in ≤1s on a typical device; total end-to-end time is additionally network-bound (best-effort, not a hard assertion).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See MBNet listed as an available source (Priority: P1)

A person opening the app sees "MBNet Server" in the list of known lottery sources, so they know MBNet is a source they can sync data from — regardless of whether they have ever synced it before.

**Why this priority**: Without MBNet appearing in the list, no other MBNet behavior is reachable. This is the smallest slice that replaces the current empty/stub listing with a real, permanently available MBNet entry.

**Independent Test**: Launch the app with no previously synced data and confirm "MBNet Server" appears in the sources list with a "never synced" (empty metadata) state. Delivers value because the user can now discover and target MBNet.

**Acceptance Scenarios**:

1. **Given** the app has never synced any source, **When** the user views the sources list, **Then** "MBNet Server" is present as a known source with no sync date, no record count, and no record dates.
2. **Given** MBNet has been synced previously, **When** the user views the sources list, **Then** "MBNet Server" is present showing its last known sync metadata.

---

### User Story 2 - Sync real draw data from MBNet (Priority: P1)

A person selects MBNet and triggers a sync. The app fetches the actual draw history from the MBNet server over the network, stores it, and updates MBNet's displayed metadata (last sync time, total record count, earliest and latest record dates) to reflect the real data that was retrieved.

**Why this priority**: This is the core purpose of the feature — turning MBNet from a stub into a source that returns genuine data. It is what "real source" means.

**Independent Test**: With network access to the MBNet server, trigger a sync of MBNet and confirm that afterward MBNet shows a non-empty record count, a first/latest record date derived from the fetched draws, and a last-sync timestamp. Delivers value because the user now holds real MBNet draw history.

**Acceptance Scenarios**:

1. **Given** MBNet is listed and the server is reachable, **When** the user triggers a sync, **Then** the app retrieves the full available draw history, stores it, and the MBNet source card immediately reflects the updated analytics — record count, last-sync time, and earliest/latest record dates — without an app restart or manual reload.
2. **Given** MBNet was synced before, **When** the user syncs again, **Then** the stored data reflects the latest available draws and the metadata is refreshed (no duplicate or lost records).
3. **Given** the MBNet server is unreachable or returns an unusable response, **When** the user triggers a sync, **Then** the sync reports a failure, an alert dialog describing the failure is presented, and the previously stored MBNet metadata is left unchanged.
4. **Given** the MBNet card is idle, **When** the user taps its "Refresh" button, **Then** a sync begins and the button switches to "Refreshing…" with a continuously rotating icon.
5. **Given** a refresh is in progress, **When** it finishes (success or failure), **Then** the button returns to "Refresh" with no animation — on success the card's analytics update, and on failure an alert dialog is presented.

---

### User Story 3 - Retain each draw's numbers, not just counts (Priority: P2)

Each synced MBNet draw is stored with its draw date and the set of drawn numbers, so that later features (statistics, history views, analysis) can rely on complete per-draw records rather than only aggregate counts.

**Why this priority**: The parsed numbers are required for the app's eventual analytical purpose, but the source is already useful (discoverable + counts + date range) without exposing numbers in the UI yet. It is therefore a fast-follow to the P1 sync, not a blocker for it.

**Independent Test**: After syncing MBNet, inspect the stored records and confirm each retained draw carries both its date and its full set of drawn numbers matching the MBNet server's published results.

**Acceptance Scenarios**:

1. **Given** a successful MBNet sync, **When** stored draws are examined, **Then** each draw has a date and the complete set of numbers reported by MBNet for that draw.
2. **Given** a draw in the MBNet response is missing its numbers or date, **When** the response is processed, **Then** that individual draw is skipped without failing the whole sync, and the skip is surfaced (logged/reported).

---

### Edge Cases

- **Empty history**: MBNet server responds successfully but with zero draws → MBNet shows a successful sync with a record count of 0 and no record dates.
- **Partial/malformed response**: Some draws are well-formed and some are not → well-formed draws are stored; malformed draws are skipped; the sync still succeeds if the response as a whole is parseable.
- **Network failure / timeout**: The server cannot be reached → sync fails cleanly, prior stored data and metadata are preserved, and the user is informed via an alert dialog.
- **Server error status**: MBNet returns an error (non-success) status → treated as a fetch failure, not as an empty history.
- **Re-sync consistency**: Repeated syncs must not create duplicate records for draws already stored (de-duplicated by ordinal index), and must never drop previously stored draws — including any that are no longer present in a later response (additive union).
- **Schema drift**: MBNet changes its response shape → the app fails the sync gracefully rather than storing corrupted data.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose "MBNet Server" as a permanently available (statically registered) known source, present in the sources list whether or not it has ever been synced.
- **FR-002**: The system MUST retrieve MBNet draw data from the MBNet server over the network on demand when the user syncs the MBNet source.
- **FR-003**: The system MUST parse the MBNet server response into individual draw records, capturing every field available for a record: the draw's ordinal index, its draw date, and all six drawn numbers.
- **FR-004**: The system MUST persist synced MBNet draw records to local storage so they survive app restarts, retaining every captured field per record (index, date, numbers).
- **FR-005**: After a successful sync, the system MUST update MBNet's source metadata — last sync time, total record count, earliest record date, and latest record date — from the stored data.
- **FR-011**: The system MUST persist MBNet's source-level metadata (last refresh time, record count, earliest/latest record dates) locally so that the last-known sync state is shown after an app restart without re-fetching.
- **FR-012**: The system MUST normalize each record's server-supplied date string (`DD.MM.YYYY`) into an efficient internal date representation at ingest time, so that stored records can be read, sorted, and range-queried without re-parsing date strings on every access.
- **FR-016**: The existing source card MUST continue to display every field it shows today — source display name, record count, last-sync status, earliest record date, and latest record date. This change MUST NOT remove, hide, or regress any of these existing card fields for MBNet or any other source.
- **FR-017**: After a fetch/refresh completes, the source card MUST update its displayed analytics — record count, last-sync status/time, earliest record date, and latest record date — to reflect the newly synced data, without an app restart or manual reload. On a failed fetch, the card MUST retain its previously displayed analytics unchanged. The individual draws' numbers are stored but MUST NOT be displayed.
- **FR-018**: Each source card MUST provide a "Refresh" button that, when tapped, forces an on-demand sync (fetch/refresh) of that card's source.
- **FR-019**: While that source's refresh is in progress, the Refresh button MUST indicate progress — its label reads "Refreshing…" and its icon animates with a continuous rotation. When the refresh finishes (whether it succeeds or fails), the button MUST return to its idle state: label "Refresh" and no animation.
- **FR-020**: While a source's refresh is in progress, tapping its Refresh button again MUST NOT start a second concurrent sync of that source.
- **FR-006**: When the MBNet server is unreachable, returns an error status, or returns a response that cannot be parsed at all, the system MUST report the sync as a failure and leave previously stored MBNet data and metadata unchanged.
- **FR-021**: On a failed refresh, the system MUST present an alert dialog informing the user that the sync failed; the user dismisses it, after which the card returns to its idle state with its prior analytics intact.
- **FR-007**: When individual draws within an otherwise valid response are malformed (missing date or numbers), the system MUST skip those draws, continue processing the rest, and surface that some records were skipped.
  *(Surfacing delivered by spec 005 — `specs/005-skipped-rows-note/`: a note on the source card with the last successful sync's skipped count.)*
- **FR-008**: Re-syncing MBNet MUST reconcile fetched draws with stored draws as an **additive union** keyed on the ordinal index: new draws are added, existing draws (same index) are updated, and previously stored draws are never deleted — even if a later fetch no longer includes them. No duplicate records are created.
- **FR-009**: The system MUST display MBNet's metadata to the user consistent with how other sources are shown (never-synced state vs. populated state).
- **FR-010**: The MBNet integration MUST NOT change the behavior or listing of any other source.

### Key Entities *(include if feature involves data)*

- **Source (MBNet)**: A named lottery data source with a stable identifier (`mbnet`) and human-readable display name ("MBNet Server"), plus derived sync metadata — last sync time, record count, earliest record date, latest record date. Metadata is empty until the first successful sync.
- **Draw record**: A single MBNet draw. Every field the server publishes for a record is retained: the draw's **ordinal index** (sequential position in MBNet's history, e.g. `7380`), its **draw date**, and the **six drawn numbers** (each in the range 1–49). This is the atomic unit fetched, parsed, and stored. The draw's identity for de-duplication is its **ordinal index** — draw dates are NOT unique (multiple draws can share a date; 6,424 distinct dates across 7,380 rows), so date alone cannot identify a draw.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: "MBNet Server" appears in the sources list 100% of the time the app is opened, including on a fresh install with no synced data.
- **SC-002**: After a successful sync against a reachable MBNet server, the displayed record count and earliest/latest record dates match the draws actually returned by the server (verifiable by comparing stored records to the server's published results).
- **SC-003**: Every stored MBNet draw retains both its date and its full set of drawn numbers — no stored draw is missing either.
- **SC-004**: When the server is unreachable or the response is unusable, the sync surfaces a failure and 0% of previously stored MBNet records or metadata are altered.
- **SC-005**: Running two consecutive syncs against the same server state produces the same stored record set (no duplicates, no losses), even though the server re-serves the full history each time.
- **SC-006**: Parsing and persisting MBNet's complete history (~7,400 records at the time of writing) completes in ≤1 second on a typical device (measured excluding network transfer, which is best-effort); reading stored records afterward requires no re-parsing of date strings.
- **SC-007**: The source card continues to show all five existing fields (display name, record count, last-sync status, earliest record date, latest record date) for every source; none are lost or regressed by this change.
- **SC-008**: Immediately after a successful refresh (no app restart or manual reload), the MBNet card's displayed record count and earliest/latest record dates match the freshly stored data, and the last-sync status reflects the just-completed sync. After a failed refresh, the card's displayed analytics are unchanged from before the attempt.
- **SC-009**: The Refresh button reflects sync state accurately — it shows the "Refreshing…" label with the rotating icon for the full duration of an in-progress sync and returns to the idle "Refresh" state once the sync ends, with no cases of a button left stuck in the refreshing state after completion.
- **SC-010**: 100% of failed refreshes present an alert dialog to the user; no failure is left silent, and dismissing the alert leaves the card's prior analytics unchanged.

## Assumptions

- **MBNet identity**: MBNet is the existing source referenced in the codebase by identifier `mbnet` / display name "MBNet Server"; this feature makes that existing stub source real rather than introducing a new named source.
- **Access method**: MBNet data is obtained from the public endpoint **`http://www.mbnet.com.pl/dl.txt`** — a plain-text file, one draw per line, in the format `<index>. DD.MM.YYYY n,n,n,n,n,n` (ordinal index, day-month-year date, six comma-separated numbers each 1–49; Polish Lotto 6/49). The file is the **complete history** (from 1957) re-served in full on every request — there is no incremental/delta endpoint — so a sync always processes the whole file (~7,400 rows / ~256 KB at time of writing).
- **HTTP transport**: The endpoint is served over plain **HTTP**, not HTTPS. The app must be configured to permit this specific host (an App Transport Security exception or equivalent). Migrating MBNet to HTTPS is out of the app's control and out of scope.
- **Record contents**: A "full draw record" is the ordinal index + draw date + the six drawn numbers — i.e. all fields the file exposes. There are no additional per-draw fields to capture.
- **Registration**: MBNet is a hard-coded built-in source (matching the existing static source-module pattern), not discovered dynamically from the server.
- **Sync trigger**: Sync is user-initiated via the existing sources UI; automatic/background syncing and scheduling are out of scope.
- **Scope boundary**: This feature covers listing MBNet, fetching, parsing, storing all fields (including the numbers), and reflecting source metadata on the existing card. **Displaying the individual draws/numbers as a list or detail view is out of scope for this change** (records are stored for later use); analytics/statistics over the numbers and multi-source aggregation also remain out of scope.
- **Connectivity**: The user has network access when they trigger a sync; offline behavior beyond a clean failure message is out of scope.
