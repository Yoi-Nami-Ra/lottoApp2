# Feature Specification: Chain-Builder Design Gaps

**Feature Branch**: `006-chain-builder-design-gaps`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "LTA-33 — Close chain-builder UI gaps against its designs. LTA-23 built the chain list, chain editor and add-block sheet before their designs were approved; the finals (design/final/add-block-sheet.html, chain-builder.html, chain-list.html, approved 2026-09-30) keep items the build lacks. Scope: (1) add-block sheet and parameter step — the parent-size hint under x, the edit hint ('Was 100. Saving marks this block's results out of date.'), the direction preview line, z bounded to 2 … x − 1 when the source's draw size is known, disabled rows read '<block>, unavailable, <reason>', an adjustable stepper, field and stepper stacking at accessibility sizes; (2) chain editor — '+' labelled 'Add block under <block>', rows read '<block>, <parameter>, level <n>, <summary or state>', at accessibility sizes the summary wraps under the title and the indent shrinks to 12 pt; (3) chain list — the 'No chains yet' empty state, a leading swipe 'Rename', Delete in the long-press menu, Rename and Delete as accessibility actions. Out of scope: anything the finals change beyond this list. Done when every item matches design/final/, TestStore tests cover the hints' inputs, the z upper bound (valid, invalid, unknown draw size) and rename from the swipe, and #Previews cover the empty chain list and the new hints, light and dark."

## Clarifications

### Session 2026-10-01

- Q: When does the editor know the source's draw size? → A: When the editor opens, if the source has stored draws (read once on opening); refreshed whenever a run reads the source; unknown only for a source with no stored draws.
- Q: How should the source row read to VoiceOver? → A: "<source name>, source, <N> draws", omitting the count when unknown.
- Q: Should a folded row's reading include how many blocks it hides? → A: Yes — "<N> hidden" follows the parameter part, as on screen.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Parameter step explains what a value means (Priority: P1)

A person adds or edits a block and sets its parameter. The parameter step tells them what their choice means in context: how many draws or items the parent produced last time (so they know when a larger x would keep them all), what the value was before an edit and that saving makes the block's results out of date, and in plain words what a sort direction does.

**Why this priority**: These hints are the bulk of the design gap and the part most likely to prevent a wrong chain: a filter that silently keeps everything, or an edit whose consequence is unexpected.

**Independent Test**: Open the parameter step for a filter under a parent whose last run produced 7,012 draws, for an edit of a block whose x was 100, and for each sort block; the hint lines read as in the design.

**Acceptance Scenarios**:

1. **Given** a chain that has run and whose parent of the new block produced 7,012 draws, **When** the person opens the parameter step for a filter (Drop First, Drop Last, Prefix, Suffix), **Then** under x it reads "Of 7,012 draws. A larger x keeps them all."
2. **Given** the parent's last run produced 49 counted items, **When** the person opens the parameter step for a filter on counts, **Then** under x it reads "Of 49 items. A larger x keeps them all."
3. **Given** the new block goes directly under the source and the source's record count is known (7,012), **When** the parameter step opens for a filter, **Then** it reads "Of 7,012 draws. A larger x keeps them all."
4. **Given** the parent has no value yet (never run, running, failed) and, for the source, its record count is unknown, **When** the parameter step opens, **Then** no parent-size hint is shown.
5. **Given** a Suffix block whose x is 100, **When** the person opens it for editing, **Then** the hint reads "Was 100. Saving marks this block's results out of date." and it keeps showing the original value while x is changed.
6. **Given** a sort block being edited whose direction was Descending, **When** the parameter step opens, **Then** the hint reads "Was Descending. Saving marks this block's results out of date."
7. **Given** the Sort by Count parameter step with Descending selected, **When** it is shown, **Then** a preview line under the control reads "Most frequent first."; switching to Ascending changes it to "Least frequent first."
8. **Given** Sort by Date or Sort by Index, **When** a direction is selected, **Then** the preview reads "Oldest first." / "Newest first." (date) or "Lowest index first." / "Highest index first." (index).

---

### User Story 2 - Sub-combination size is bounded by the source's draw size (Priority: P1)

A person adds or edits a Count Unique Sub-combinations block. When the app knows how many numbers each draw of the chosen source has (x), it only accepts z from 2 to x − 1 at entry time, instead of letting the run fail later.

**Why this priority**: It turns a run-time failure ("z must be below this source's draw size") into an immediate, explained correction, and it is one of the ticket's named test obligations.

**Independent Test**: With a source whose draws have 6 numbers, type z = 5 (accepted), z = 6 (refused with the bounded message), and use "+" up to 5 (then disabled); with an unknown draw size, z = 6 is accepted.

**Acceptance Scenarios**:

1. **Given** the source's draws have 6 numbers, **When** the person enters z = 5, **Then** the value is valid and Add/Save is enabled.
2. **Given** the source's draws have 6 numbers, **When** the person enters z = 6 (or more), **Then** the message "Enter a whole number from 2 to 5." is shown and Add/Save is disabled.
3. **Given** the source's draws have 6 numbers and z = 5, **When** the parameter step is shown, **Then** the "+" is disabled; at z = 4 it is enabled and moves z to 5.
4. **Given** the source's draw size is unknown (the source has no stored draws), **When** the person enters z = 6, **Then** only z ≥ 2 is checked, the value is accepted, and a too-large z fails at run time as it does today.
5. **Given** the source's draws have 6 numbers, **When** the person enters z = 1 or leaves it empty, **Then** the message "Enter a whole number from 2 to 5." is shown and Add/Save is disabled.

---

### User Story 3 - Chain list: empty state, rename and delete everywhere (Priority: P2)

A person on the chain list sees a short explanation before their first chain, can rename a chain by swiping right or from its long-press menu, and can delete a chain by swiping left or from its long-press menu. VoiceOver users reach Rename and Delete as actions on each row.

**Why this priority**: It completes the chain list against its final design; the operations already exist, only their reachability and the empty state are missing.

**Independent Test**: Open the chain list with no chains (empty state visible above New chain); add chains; rename one via the leading swipe; delete one via the long-press menu; check VoiceOver actions.

**Acceptance Scenarios**:

1. **Given** no saved chains and the list has finished loading, **When** the chain list is shown, **Then** "No chains yet" and "A chain is a set of blocks that counts and sorts a source's draws. Tap New chain to build your first one." appear above the New chain row.
2. **Given** at least one chain, **When** the list is shown, **Then** the empty state is not shown.
3. **Given** a chain "Hot numbers", **When** the person swipes the row right and taps Rename, **Then** the rename alert opens with "Hot numbers" ready to edit; saving a new non-blank, different name renames the chain; a blank or unchanged name is ignored.
4. **Given** a chain, **When** the person long-presses it, **Then** the menu offers Rename and Delete; Delete asks for confirmation exactly as the trailing swipe does.
5. **Given** VoiceOver is on, **When** focus is on a chain row, **Then** it reads "<name>, <N> blocks" and offers Rename and Delete as actions.

---

### User Story 4 - Chain editor reads correctly with VoiceOver and large text (Priority: P3)

A VoiceOver user hears each outline row as one sentence — the block, its parameter, its depth and its summary or state — and each "+" names the block it adds under. At accessibility text sizes the outline stays readable: the summary moves under the title and nesting takes less width.

**Why this priority**: Accessibility completeness for a screen that is already functional.

**Independent Test**: With VoiceOver, focus a row and the "+" beside it; at an accessibility text size, check the row layout and indent.

**Acceptance Scenarios**:

1. **Given** a Suffix block with x = 100 at level 1 whose last run produced 100 draws, **When** VoiceOver focuses its row, **Then** it reads "Suffix, last 100, level 1, 100 draws".
2. **Given** a block that has not run, is running, failed or is out of date, **When** VoiceOver focuses its row, **Then** the last part reads its state as shown on screen ("Not run", "Running", the failure reason, or the summary followed by "Out of date").
3. **Given** a block without parameters, **When** VoiceOver focuses its row, **Then** the parameter part is omitted ("Count Unique Elements, level 2, 49 elements").
4. **Given** the "+" on the Suffix row, **When** VoiceOver focuses it, **Then** it reads "Add block under Suffix"; on the source row it reads "Add block under <source name>".
5. **Given** an accessibility text size, **When** the outline is shown, **Then** each row's summary or state wraps under the block title instead of sitting to its right, and each level indents 12 pt instead of 22 pt.

---

### User Story 5 - Add-block sheet accessibility (Priority: P3)

A VoiceOver user hears why a catalogue row is disabled, can adjust the number with swipe up/down, and at accessibility text sizes the number field and stepper stack vertically.

**Why this priority**: Accessibility completeness for the add-block sheet.

**Independent Test**: With VoiceOver, focus a disabled catalogue row and the stepper; at an accessibility text size, check the parameter layout.

**Acceptance Scenarios**:

1. **Given** Sort by Count under a draws parent, **When** VoiceOver focuses its row, **Then** it reads "Sort by Count, unavailable, Needs counts — add a count block first".
2. **Given** the x or z stepper, **When** VoiceOver focuses it, **Then** it is adjustable: swipe up increments and swipe down decrements, honouring the same bounds as the buttons.
3. **Given** an accessibility text size, **When** the parameter step shows a number field, **Then** the field and the stepper stack vertically instead of sharing one line.

---

### Edge Cases

- The list is still loading: the empty state is not shown until the chains have been read, so it doesn't flash before existing chains appear.
- The last chain is deleted: the empty state appears.
- Rename is started and the chain is deleted before the alert is confirmed (e.g. from another path): the rename is ignored.
- The parent's result is out of date: the parent-size hint still shows its last known size (it is labelled as the previous run's size by being "Of N", not a promise).
- The parent is a count-all block (a single number): it can never be a parent, so no hint case arises.
- The source's draw size is 2 or less: no z from 2 to x − 1 exists; every z is refused with "This source's draws are too small for sub-combinations." and Add/Save stays disabled.
- The draw size becomes known while the parameter step is open (not possible: the step is modal and nothing reads the source meanwhile); the bound is taken when the step opens.
- Editing z on a block whose saved z is now above the bound (e.g. it was set before the draw size was known): the step opens with that value, shows the bounded message, and Save stays disabled until it is corrected.
- Invalid input in edit mode: the validation message takes the hint's place; the "Was …" hint returns as soon as the input is valid again.
- One-block and single-item wording: "Of 1 draw." / "Of 1 item." and "1 block" in the row reading.

## Requirements *(mandatory)*

### Functional Requirements

**Add-block sheet and parameter step (design/final/add-block-sheet.html)**

- **FR-001**: When adding a filter (x), the parameter step MUST show a parent-size hint "Of <N> draws. A larger x keeps them all." (draws parent) or "Of <N> items. A larger x keeps them all." (counts parent) when the parent's size is known, using singular "draw"/"item" for 1 and grouped digits.
- **FR-002**: The parent's size MUST be known when the parent block's current result in the editor is a value (draws: its number of draws; counts: its number of items), or, for a block directly under the source, when the source's record count is known. Otherwise no parent-size hint is shown.
- **FR-003**: When editing a block with a parameter, the parameter step MUST show "Was <original value>. Saving marks this block's results out of date.", where the original value is the block's value when editing started (a number for x or z, "Ascending"/"Descending" for a direction). In edit mode this hint replaces the parent-size hint.
- **FR-004**: Sort parameter steps MUST show a one-line preview under the direction control that follows the selection: Sort by Count — "Most frequent first." (descending) / "Least frequent first." (ascending); Sort by Date — "Oldest first." / "Newest first."; Sort by Index — "Lowest index first." / "Highest index first." (ascending / descending).
- **FR-005**: When the chosen source's draw size x is known, z MUST be valid only for whole numbers 2 … x − 1; otherwise the message "Enter a whole number from 2 to <x − 1>." is shown and Add/Save is disabled.
- **FR-006**: When the draw size is known, the z stepper's "+" MUST be disabled at x − 1 (and increment never moves z above x − 1).
- **FR-007**: When the draw size is unknown, z MUST be checked only against z ≥ 2 (today's rule and message), leaving a too-large z to fail at run time.
- **FR-008**: When the draw size is 2 or less, every z MUST be refused with "This source's draws are too small for sub-combinations." and Add/Save disabled.
- **FR-009**: The source's draw size (the number of elements in each of its draws) MUST be read when the chain editor opens, if the source has stored draws, and refreshed whenever a run reads the source successfully (a failed read leaves it unchanged); a source with no stored draws has an unknown draw size.
- **FR-010**: Disabled catalogue rows MUST read to assistive technologies as "<block>, unavailable, <reason>".
- **FR-011**: The x/z stepper MUST be exposed as an adjustable control (increment/decrement actions honouring the same bounds as the buttons).
- **FR-012**: At accessibility text sizes the number field and the stepper MUST stack vertically.

**Chain editor (design/final/chain-builder.html)**

- **FR-013**: Each "+" MUST be labelled "Add block under <block>" (the block's title), or "Add block under <source name>" on the source row.
- **FR-014**: Each block row MUST read as one element: "<block>, <parameter>, level <n>, <summary or state>", omitting the parameter part for blocks without one; the state is what the row shows ("Not run", "Running", the failure reason, "Not run — an earlier block failed", or the summary, followed by "Out of date" when stale), a folded row adds "<N> hidden" after the parameter part, and "Saved" is appended when the result is saved. The source row reads "<source name>, source, <N> draws", omitting the count when unknown.
- **FR-015**: At accessibility text sizes each row's summary or state MUST wrap under the block title and the indent per level MUST be 12 pt instead of 22 pt.

**Chain list (design/final/chain-list.html)**

- **FR-016**: With no chains, once the list has loaded, the page MUST show the empty state — the ƒ icon, "No chains yet", and "A chain is a set of blocks that counts and sorts a source's draws. Tap New chain to build your first one." — above the New chain row.
- **FR-017**: Each chain row MUST offer a leading swipe "Rename" (primary blue) that opens the same rename alert as the long-press item, prefilled with the current name; a blank or unchanged name is ignored.
- **FR-018**: The long-press menu MUST offer Rename and Delete; Delete MUST follow the same confirm-first flow as the trailing swipe.
- **FR-019**: Each chain row MUST read "<name>, <N> blocks" ("1 block") and expose Rename and Delete as accessibility actions.
- **FR-020**: The rename flow (which chain is being renamed and its draft name) MUST be feature state, so rename started from the swipe, the menu or the accessibility action behaves identically and is testable.

**Cross-cutting**

- **FR-021**: All new copy, colors, fonts and spacings MUST come from named design tokens, and every changed view MUST ship previews for the new states in light and dark (empty chain list; parent-size, edit and direction hints; z bound message).
- **FR-022**: Nothing beyond the listed items changes; any other difference from the finals is out of scope (a new ticket under LTA-20).

### Key Entities

- **Parameter context**: what the parameter step knows beyond the block — the parent's last known size and its kind (draws or items), the block's original value when editing, and the source's draw size when known.
- **Rename in progress**: the chain being renamed and the name being typed; exists only while the rename alert is shown.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every item in LTA-33's scope list matches its frame in design/final/ when compared side by side (all 12 items).
- **SC-002**: A too-large z for a source with a known draw size is refused at entry in 100% of cases; no run fails with "z must be below this source's draw size" when the draw size was known at entry.
- **SC-003**: With VoiceOver, every chain-list row offers Rename and Delete, every outline row is read in one pass with block, parameter, level and state, and every disabled catalogue row states its reason — verified on all rows of the preview fixtures.
- **SC-004**: At the largest accessibility text size, no outline row or parameter row truncates its title, summary or number field.
- **SC-005**: Automated reducer tests cover the hints' inputs (parent size for draws, counts and source; original value), the z bound (valid, invalid, unknown draw size), and rename started from the swipe, and all pass.

## Assumptions

- The parent-size hint uses the parent's current result as shown in the editor, even if out of date; the design only asks for "a previous run knows the parent's size".
- For a counts parent the hint says "items" (e.g. elements or combinations counted); the design only shows the draws wording.
- The edit hint appears for every edited block with a parameter, including direction; the design shows it for x only.
- The direction preview copy for date and index is inferred from the count example ("Most frequent first.").
- The draw size comes from the source's own game shape in its stored draws; a source with no stored draws (never synced) has none (matches the design's "never synced"). Reading a source's stored draws on opening is fast enough not to delay the editor (a few thousand draws).
- Swipe-to-delete, the delete confirmation copy, sorting and the New chain row already match the finals and are unchanged.
- Everything else in the three designs is already built (per each design ticket's "Decided").
