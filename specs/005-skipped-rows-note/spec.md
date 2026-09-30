# Feature Specification: Skipped Rows Note

**Feature Branch**: `005-skipped-rows-note`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "LTA-2 — Show users how many malformed rows were skipped. Spec 001 FR-007 requires that when some draws in an otherwise valid response are malformed, the sync continues and the app surfaces that records were skipped. Today the count only reaches a log line and never the source card. Validate fully at sync: besides the rows the parser drops, check each draw against the Domain rules (e.g. duplicate numbers) before it is saved; invalid draws are never stored, and one count covers both kinds. Show a warning note on the source card, e.g. '3 records skipped in last sync', built with design tokens and keeping the card's accessibility-size reflow. Persist the count with the source metadata so it survives relaunch; the next successful sync replaces it, a sync with 0 skipped clears the note, a failed sync leaves it unchanged. Tests first: repo sync with parser skips, Domain skips, both, and none; persistence across a store reload; a failed sync keeping the previous count; reducer/view state mapping. Previews (light/dark) for a card with and without the note, including large Dynamic Type."

## Clarifications

### Session 2026-10-01

- Q: Where on the source card should the skipped-records note sit? → A: A full-width row between the header (name, sync badge, record count) and the first/latest record details.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See that the last sync skipped records (Priority: P1)

A person refreshes a source. The download succeeds, but some of the published draws are unusable — a row is missing its date or numbers, or a draw breaks the game's rules (for example the same number appears twice, a number is outside the game's range, or the draw has the wrong number of numbers). The sync still completes with every usable draw, and the source card now shows a warning note saying how many records were skipped in the last sync, so the person knows the stored history is incomplete instead of assuming it is whole.

**Why this priority**: This is the defect in the ticket. Spec 001 FR-007 promised the skip would be surfaced; today it silently vanishes into a log, and a person analysing draws has no way to know some are missing.

**Independent Test**: Serve a source response in which some rows are malformed and some draws break the game's rules; refresh; the card shows one note whose count is the total of both kinds, and only the valid draws are stored.

**Acceptance Scenarios**:

1. **Given** a response in which 3 rows can't be read as draws and all other draws are valid, **When** the user refreshes the source, **Then** the sync succeeds, the valid draws are stored, and the card shows "3 records skipped in last sync".
2. **Given** a response in which every row can be read but 2 draws break the game's rules (e.g. a repeated number), **When** the user refreshes, **Then** those 2 draws are not stored and the card shows "2 records skipped in last sync".
3. **Given** a response with 1 unreadable row and 2 rule-breaking draws, **When** the user refreshes, **Then** the card shows a single note counting 3 skipped records.
4. **Given** a response in which every draw is valid, **When** the user refreshes, **Then** no note is shown.
5. **Given** exactly one record was skipped, **When** the card renders, **Then** the note uses the singular wording ("1 record skipped in last sync").

---

### User Story 2 - The note reflects the most recent successful sync (Priority: P2)

The note describes the last sync that succeeded, not every sync ever. It stays across app relaunches, is replaced by the next successful sync, disappears when a successful sync skips nothing, and is left as it was when a sync fails.

**Why this priority**: Without a clear lifetime the note would either vanish on relaunch (and the person would never see it if they synced and closed the app) or linger after the problem was fixed at the source. It builds on Story 1.

**Independent Test**: Sync with skips, relaunch the app, and check the note is still there; sync again with a different number of skips and check the count changes; sync with no skips and check the note is gone; make a sync fail and check the note is unchanged.

**Acceptance Scenarios**:

1. **Given** the last successful sync skipped 3 records, **When** the app is relaunched, **Then** the card still shows "3 records skipped in last sync".
2. **Given** the card shows 3 skipped records, **When** the next successful sync skips 1, **Then** the card shows "1 record skipped in last sync".
3. **Given** the card shows 3 skipped records, **When** the next successful sync skips none, **Then** the note disappears.
4. **Given** the card shows 3 skipped records, **When** the next sync fails for any reason, **Then** the failure is reported as today and the card still shows 3 skipped records.
5. **Given** a source that has never synced, **When** the card renders, **Then** no note is shown.

---

### User Story 3 - The note is readable in every appearance (Priority: P3)

The note is legible in light and dark appearance and at every text size, including the largest accessibility sizes, without breaking words mid-word or crowding the card's other rows, and it is announced by assistive technologies.

**Why this priority**: The card has already been reworked to survive the largest text sizes; the new note must not regress that. It is quality on top of Stories 1–2.

**Independent Test**: Render a card with the note in light and dark appearance at the default and the largest accessibility text size; the note wraps at word boundaries, keeps its warning look, and is read out by VoiceOver.

**Acceptance Scenarios**:

1. **Given** a card with the note, **When** it is shown at the largest accessibility text size, **Then** the note wraps at word boundaries and the card's existing reflow is unchanged.
2. **Given** a card with the note, **When** VoiceOver reads the card, **Then** the note's full text is announced.
3. **Given** a card with the note in light or dark appearance, **When** it renders, **Then** the note is clearly a warning (not an error), distinguishable without relying on colour alone.

---

### Edge Cases

- **Every draw breaks the rules**: if the response has rows but none survive both checks, the sync fails as a changed data format (the same outcome as today when no row can be read), nothing is stored, and the note from the previous successful sync is left unchanged.
- **Empty response**: a response with no rows at all is still a successful "empty history" sync with 0 skipped, so it clears any note.
- **Rule-breaking draw with the index of a stored valid draw**: the rule-breaking draw is skipped and counted; the stored valid draw is kept unchanged (the additive merge never lets an invalid draw replace a valid one).
- **Same index twice in one response**: resolved as today by the additive merge (the later row wins); it is not counted as skipped.
- **Stored metadata written before this feature**: it has no skipped count; the card treats it as 0 (no note) until the next successful sync writes one.
- **Cancelled sync**: counts as a failed sync — no alert (as today) and the note is unchanged.
- **Large counts**: the note shows the full number with the locale's grouping (e.g. "1,204 records skipped in last sync").

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: During a sync, the system MUST validate every draw that the source's parser produced against the source's game rules (exactly the game's pick count of numbers, all distinct, each within the game's pool) before saving it.
- **FR-002**: Draws that fail FR-001 MUST NOT be stored; the sync MUST continue and store every draw that passes.
- **FR-003**: The system MUST count, per successful sync, the rows the parser could not read plus the draws that failed FR-001, as one skipped-records count.
- **FR-004**: The skipped-records count MUST be persisted with the source's metadata, so it survives an app relaunch.
- **FR-005**: A successful sync MUST replace the stored skipped-records count with its own count, including replacing it with 0.
- **FR-006**: A failed or cancelled sync MUST leave the stored skipped-records count unchanged.
- **FR-007**: When the response contains rows but no draw survives both the parser and FR-001, the sync MUST fail with the existing "data format not recognised" failure and store nothing.
- **FR-008**: The source card MUST show, as a full-width row between the card's header and its first/latest record details, a warning note stating the number of records skipped in the last successful sync when that number is greater than 0, with singular and plural wording and the locale's number grouping.
- **FR-009**: The source card MUST NOT show the note when the count is 0 or the source has never synced.
- **FR-010**: The note MUST keep the card's existing layout reflow at accessibility text sizes, wrap at word boundaries, and be announced by assistive technologies.
- **FR-011**: The note MUST convey its warning status by an icon as well as colour, and MUST follow the app's design tokens in light and dark appearance.
- **FR-012**: The system MUST keep logging each sync's skipped rows for diagnostics, distinguishing unreadable rows from rule-breaking draws.
- **FR-013**: Metadata written before this feature (with no skipped-records count) MUST still load, and MUST be treated as 0 skipped.

### Key Entities *(include if feature involves data)*

- **Source**: a lottery data source as the app presents it. Gains the number of records skipped in its last successful sync (absent until the first successful sync).
- **Source metadata**: the persisted per-source sync analytics (last sync time, record count, record dates, content digest). Gains the last successful sync's skipped-records count.
- **Skipped record**: a row in a source's response that was not stored, either because it could not be read as a draw or because the draw breaks the game's rules. Only its count is kept.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of successful syncs that skip at least one record, the source card shows the exact number skipped, matching the diagnostic log for that sync.
- **SC-002**: 0 draws that break the game's rules are stored by a sync.
- **SC-003**: After an app relaunch, the note shown matches the last successful sync's count in 100% of cases.
- **SC-004**: A failed sync changes the shown note in 0% of cases.
- **SC-005**: At the largest accessibility text size, the card with the note shows no mid-word breaks in any of its labels, in both light and dark appearance.

## Assumptions

- The game rules used for FR-001 are the existing Domain rules for a combination of the source's game type (spec 003 / LTA-6); no new rules are introduced.
- Only the count is surfaced; which rows were skipped, and why, is available only in the diagnostic log.
- The note is informational: it has no action (no tap target, no retry), and it does not change the sync-severity badge or the selection behaviour.
- The note text is "N record(s) skipped in last sync", localised through the app's string resources.
- Draws already stored before this feature are not re-validated; reading stored draws keeps its existing "stored draws couldn't be read" failure (spec 004 US2) for any that break the rules.
- The only registered source is MBNet; the behaviour applies to every source module, since validation uses each source's own game type.
