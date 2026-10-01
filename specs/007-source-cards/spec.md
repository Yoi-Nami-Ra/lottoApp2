# Feature Specification: Compact and Wide Source Cards

**Feature Branch**: `007-source-cards`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "LTA-28 + LTA-29 — Compact and wide source cards on the start page. LTA-28 (design): approve design/proposal/28-source-cards.html and promote it to design/final/source-cards.html (re-render PNG, update ticket designs, delete proposal). LTA-29 (implementation): the start page switches by horizontal size class — compact width shows a compact source card list, regular width shows today's full source cards in an adaptive grid (columns of at least ~320 pt, cards in a row share height, Next bar fixed width at the trailing edge on wide screens). Compact card: one row — decorative severity dot, name (checkmark when selected, 'Not synced' inline when never synced), icon-only refresh button ('Refresh'/'Refreshing' for VoiceOver, existing spin/dim styling), chevron disclosure ('Show details'/'Hide details'); 52 pt minimum height; tapping the row outside the buttons selects the source. Expanded details inline: record count, severity-coloured last-sync badge, first and latest record dates; also LTA-2's skipped-rows note and, wherever LTA-4 lands, its '~N missing' line. Several cards may be expanded at once; collapsed by default; not persisted. The expanded flag is feature state toggled by an action. Selection, Next bar and sync behaviour unchanged. Keep LTA-3 (Fetch vs Refresh on never-synced) compatible. Accessibility: severity read from text; at accessibility text sizes the name wraps before the buttons shrink and the details become one column. Tests first: expand toggle, selection and refresh from both variants. Design tokens and light/dark previews for compact collapsed, expanded, selected, refreshing, never synced, large Dynamic Type, regular-width grid."

## Clarifications

### Session 2026-10-01

- Q: When a compact card is expanded, does tapping inside its details area select the source? → A: Yes — the whole card, details included, selects the source, except its refresh button and chevron.
- Q: Where does the skipped-records note sit inside the compact card's expanded details? → A: A full-width row between the record count / last-sync row and the first / latest record dates (the full card's spec 005 placement).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scan and choose sources on a narrow screen (Priority: P1)

On an iPhone (or an iPad in a narrow split view) the start page shows each source as one compact row: a severity dot, the source's name, a refresh button and a disclosure chevron. The person can see every source at a glance without scrolling past large cards, choose one by tapping its row, refresh it from the row, and move on with Next — exactly as they do today with the full cards.

**Why this priority**: This is the change LTA-5 asks for. Today's full card takes most of a phone screen per source, so a list of sources becomes a long scroll; the compact row fixes that, and it must not cost any of today's behaviour.

**Independent Test**: Launch the app at compact width with several sources; each is a single row at least 52 pt tall; tap a row → it shows as selected and Next enables; tap a row's refresh button → that source syncs with the existing spin and dim, and the row is not selected by the tap.

**Acceptance Scenarios**:

1. **Given** the start page at compact width with sources loaded, **When** it renders, **Then** each source appears as a one-row compact card showing a severity dot, its name, a refresh button and a chevron, and no card shows its details.
2. **Given** a compact card that is not selected, **When** the person taps the row anywhere except the refresh button or the chevron, **Then** that source becomes the selected one (highlighted border and a checkmark next to the name), any previously selected source is deselected, and Next is enabled.
3. **Given** a compact card, **When** the person taps its refresh button, **Then** that source starts syncing, the button spins and dims and is announced as "Refreshing", further taps are ignored until the sync ends, and the selection does not change.
4. **Given** a source that has never been synced, **When** its compact card renders, **Then** "Not synced" is shown inline next to the name, so the state does not depend on the grey dot alone.
5. **Given** a sync started from a compact card fails, **When** it ends, **Then** the same failure alert as today is shown and the card's previous details are unchanged.

---

### User Story 2 - Expand a compact card to see its details (Priority: P1)

The person taps a compact card's chevron to reveal that source's details inline, under the row: the record count, the last-sync badge (coloured by how overdue the sync is, as on today's card), the first and latest record dates, and — when present — the skipped-records note from the last sync. Tapping the chevron again hides them. Several cards can be open at once; every card starts closed.

**Why this priority**: Without it the compact card would hide information today's card shows. It is P1 with Story 1 because together they replace today's card on narrow screens; on its own, Story 1 would be a regression in information.

**Independent Test**: At compact width tap one card's chevron → its details appear and the chevron is announced as "Hide details"; tap another card's chevron → both are open; tap the first again → only the second stays open; relaunch → all are closed.

**Acceptance Scenarios**:

1. **Given** a collapsed compact card, **When** the person taps its chevron, **Then** the card shows its details inline — record count, last-sync badge, first record and latest record — and the chevron flips to point up and is announced as "Hide details".
2. **Given** an expanded compact card, **When** the person taps its chevron, **Then** the details are hidden and the chevron is announced as "Show details".
3. **Given** one expanded card, **When** the person expands a second card, **Then** both stay expanded.
4. **Given** a compact card, **When** the person taps its chevron, **Then** the selection does not change and no sync starts.
5. **Given** the last successful sync of a source skipped records, **When** its compact card is expanded, **Then** the skipped-records note is shown in the details as a full-width row between the record count / last-sync row and the first / latest record dates, worded as on today's card.
6. **Given** a source that has never synced, **When** its compact card is expanded, **Then** the details show the same "N/A" placeholders today's card shows for a never-synced source.
7. **Given** some cards were expanded, **When** the app is relaunched, **Then** every card starts collapsed.
8. **Given** some cards are expanded, **When** the source list reloads (for example on returning from the next screen) or a source finishes syncing, **Then** those cards stay expanded.
9. **Given** an expanded compact card that is not selected, **When** the person taps inside its details, **Then** that source becomes the selected one.

---

### User Story 3 - See several full cards side by side on a wide screen (Priority: P2)

On an iPad or a Mac window of regular width, the start page keeps today's full source card unchanged but lays the cards out in a grid, so several sources sit side by side. The Next button keeps a fixed width at the trailing edge instead of stretching across the whole screen.

**Why this priority**: Wide screens work today, just wastefully (one stretched card per row). The grid is an improvement, not a fix, and it depends on nothing in Stories 1–2.

**Independent Test**: Run at regular width with several sources; the cards form columns of at least ~320 pt each (three on a landscape iPad, fewer when narrower); cards in one row have the same height; Next sits at the trailing edge with a fixed width; selection and refresh work as today.

**Acceptance Scenarios**:

1. **Given** the start page at regular width, **When** it renders, **Then** each source is shown as today's full card, and the cards are laid out in as many columns as fit with each column at least ~320 pt wide.
2. **Given** cards of different content heights in one grid row, **When** they render, **Then** every card in that row has the row's height.
3. **Given** the start page at regular width, **When** it renders, **Then** the Next button has a fixed width and sits at the trailing edge of the bottom bar.
4. **Given** the start page at regular width, **When** the person taps a card or its Refresh button, **Then** selection and sync behave exactly as they do today.
5. **Given** an iPad or Mac window whose width changes between compact and regular (split view, window resizing), **When** the width class changes, **Then** the page switches between compact cards and the full-card grid, keeping the selection, any in-flight sync, and each compact card's expanded state.

---

### User Story 4 - Use the compact card with assistive technologies and large text (Priority: P3)

A person using VoiceOver hears each compact card as the source's name with its sync status in words (for example "MBNet Server, Last synced: 27 Sep 2026 at 09:12", or "Not synced"), and the two buttons as "Refresh"/"Refreshing" and "Show details"/"Hide details". At the largest text sizes the name wraps onto more lines before the buttons shrink, and the expanded details stack into one column, with no words broken mid-word.

**Why this priority**: The full card was already reworked for accessibility sizes; the new compact card must meet the same bar. It is quality on top of Stories 1–2.

**Independent Test**: With VoiceOver on, swipe through a compact card and check the three announcements; render a compact card, collapsed and expanded, at the largest accessibility text size in light and dark appearance and check the name wraps, the buttons keep their size, and the details are one column.

**Acceptance Scenarios**:

1. **Given** VoiceOver is on, **When** it reaches a compact card's row, **Then** it announces the name, the selected state when selected, and the sync status as text; the severity dot is not announced on its own.
2. **Given** VoiceOver is on, **When** it reaches the refresh button and the chevron, **Then** they are announced as "Refresh" (or "Refreshing" while syncing) and "Show details" (or "Hide details" when expanded).
3. **Given** the largest accessibility text size, **When** a compact card renders, **Then** the name wraps at word boundaries and the refresh button and chevron keep their size.
4. **Given** the largest accessibility text size, **When** a compact card is expanded, **Then** its details are laid out in one column.

---

### User Story 5 - Approve the design the build follows (Priority: P3)

The LTA-28 proposal becomes the approved design that the implementation is checked against: it is moved into the approved designs, its snapshot is re-rendered, and the design and implementation tickets point at it.

**Why this priority**: It is bookkeeping that the design lifecycle requires (design/README.md) before the implementation ticket can close; it changes no app behaviour.

**Independent Test**: The approved design file and its snapshot exist under the approved designs, the proposal is gone, LTA-28 is done with its `designs` pointing at the approved file, and LTA-29's `designs` lists the same file.

**Acceptance Scenarios**:

1. **Given** the proposal for LTA-28, **When** this feature is done, **Then** an approved design exists as `design/final/source-cards.html` with a re-rendered `design/final/source-cards.png`, and the proposal files are removed.
2. **Given** the approved design, **When** the tickets are inspected, **Then** LTA-28's `designs` lists only `design/final/source-cards.html`, LTA-28 is done, and LTA-29's `designs` lists `design/final/source-cards.html`.
3. **Given** this specification's decisions (for example, where the skipped-records note sits on the compact card), **When** they differ from or add to the proposal, **Then** the approved design shows them.

---

### Edge Cases

- **A single source**: it is selected automatically, as today; its compact card shows the checkmark and selected border from the start.
- **No sources / still loading**: the empty and loading states are unchanged at both widths.
- **Width changes mid-sync**: the sync keeps running and the variant shown after the switch reflects it (the spinning icon button, or the full card's spinning Refresh).
- **Width changes while expanded**: the expanded state is kept while the full-card grid is shown and reappears when the page returns to compact width; the full card ignores it.
- **Tapping refresh on a card that is mid-sync**: ignored, from either variant (no second concurrent sync).
- **A source removed by a reload**: its expanded state goes with it; a source added by a reload starts collapsed.
- **Very long source name**: on the compact row the name wraps; the refresh button and chevron are never pushed off the row or shrunk.
- **Missing-records line (LTA-4)**: not built yet; when it is, it sits in the compact card's expanded details next to the skipped-records note, so no compact-row change is needed.
- **Never-synced action wording (LTA-3)**: not built yet; the compact refresh button stays icon-only, so LTA-3 changes only its accessibility label ("Fetch" for a never-synced source), not the row's layout.
- **One grid column at regular width**: if a regular-width window is too narrow for two ~320 pt columns, the grid shows one column of full cards.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The start page MUST choose the card variant by the available width class, not by device or platform: compact width → compact cards in a single column; regular width → today's full cards in a grid.
- **FR-002**: A compact card MUST show, in one row, a severity dot, the source's name, a refresh button and a disclosure chevron, with a minimum row height of 52 pt.
- **FR-003**: A compact card's name MUST be followed by a checkmark when the source is selected, and by the text "Not synced" when the source has never synced; a selected compact card MUST also show a highlighted border, as the full card does.
- **FR-004**: Tapping a compact card anywhere except its refresh button or chevron — including inside its expanded details — MUST select that source, following the existing selection rules (one selection at a time; a single source is selected automatically).
- **FR-005**: The compact card's refresh button MUST start a sync of that source exactly as the full card's Refresh does today — including ignoring taps while that source is syncing, the spinning and dimmed look while syncing, and the existing failure alerts — and MUST NOT change the selection.
- **FR-006**: The compact card's refresh button MUST show an icon only, and MUST be announced as "Refresh", or "Refreshing" while the source is syncing.
- **FR-007**: Tapping a compact card's chevron MUST toggle that card's details between hidden and shown, without changing the selection or starting a sync.
- **FR-008**: A compact card's details MUST show the record count, the last-sync badge coloured by sync severity (as on today's card), the first record date and the latest record date, using the same "N/A" placeholders as today's card when a value is missing.
- **FR-009**: A compact card's details MUST show the skipped-records note (spec 005), when the last successful sync skipped records, as a full-width row between the record count / last-sync row and the first / latest record dates; the missing-records line of LTA-4, once built, MUST also sit in the details.
- **FR-010**: Each compact card's expanded state MUST be independent of the others (several may be expanded at once), MUST start collapsed, MUST NOT be persisted across launches, and MUST survive a reload of the source list, a completed or failed sync, and a switch between width classes.
- **FR-011**: The chevron MUST point down when collapsed and up when expanded, and MUST be announced as "Show details" when collapsed and "Hide details" when expanded.
- **FR-012**: The severity dot MUST be decorative for assistive technologies; a compact card's row MUST announce the source's name, its selected state, and its sync status as text.
- **FR-013**: At accessibility text sizes, the compact row MUST let the name wrap at word boundaries before the refresh button or chevron shrink, and the expanded details MUST be laid out in a single column.
- **FR-014**: At regular width, the start page MUST lay out today's full cards, unchanged, in a grid of as many columns as fit with each column at least ~320 pt wide, and every card in a grid row MUST take that row's height.
- **FR-015**: At regular width, the Next button MUST have a fixed width and sit at the trailing edge of the bottom bar; at compact width it stays full width as today.
- **FR-016**: Selection, the Next button's enabling and navigation, and sync behaviour MUST be identical from both card variants.
- **FR-017**: The compact card and the grid MUST follow the app's design tokens (colours reusing the existing severity and refresh tokens; new named tokens for the dot size, compact row height and padding, and the grid's minimum column width) in light and dark appearance.
- **FR-018**: The LTA-28 proposal MUST be promoted to the approved design `design/final/source-cards.html` with a re-rendered `.png`, reflecting this specification's decisions; the proposal MUST be removed; LTA-28 MUST be closed with its `designs` pointing at the approved file, and LTA-29's `designs` MUST list it.

### Key Entities *(include if feature involves data)*

- **Source entry**: one source as the start page presents it (name, sync analytics, severity, selected, syncing). Gains whether its compact card is expanded — screen state only, never stored.
- **Approved design**: the self-contained design file, with its snapshot, that the implementation is built and checked against; referenced from the design and implementation tickets.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On an iPhone-width screen, a start page with four collapsed sources fits on one screen without scrolling (each card a single row of at least 52 pt).
- **SC-002**: Every action available on today's card (select, refresh, read record count, last sync, first and latest record, skipped note) is reachable from a compact card in at most one tap.
- **SC-003**: Selection and refresh outcomes are identical from both variants in 100% of the covered scenarios (selection moves, single-source auto-select, ignored refresh while syncing, failure alert, cancelled sync).
- **SC-004**: At the largest accessibility text size, compact cards collapsed and expanded show no mid-word breaks and no shrunken buttons, in both light and dark appearance.
- **SC-005**: On a landscape iPad, at least three full cards sit side by side in one row.
- **SC-006**: VoiceOver announces the sync status and both button labels for 100% of compact cards, and never announces the severity dot on its own.

## Assumptions

- "Compact" and "regular" are the platform's horizontal size classes; iPad split view and Mac window resizing follow them with no platform checks (LTA-5's decision).
- The full card is today's card, unchanged, including its accessibility-size reflow and its skipped-records note placement (spec 005); only its layout in a grid is new.
- The compact row's sync status text for VoiceOver reuses the full card's last-sync wording ("Last synced: <date and time>", or "Not synced"); no new relative-date wording is introduced, so the design's "1 day ago" is illustrative.
- The last-sync badge, record count and date formats in the compact details are the same as on the full card.
- Only MBNet exists as a source today; the other sources in the design are illustrative, and the layout is verified with previews that use several sample sources.
- LTA-3 (Fetch vs Refresh) and LTA-4 (missing records) are not built; this feature only leaves room for them as described in Edge Cases and does not build them.
- The approved design's snapshot is rendered with the headless Chrome command in design/README.md.
