# Feature Specification: Source Selection, Bottom Action Bar & Processing Blocks Page

**Feature Branch**: `002-blocks-page-navigation`

**Created**: 2026-08-15

**Status**: Draft

**Input**: User description: "Add a bar on the bottom of the screen where the list of sources ends. This bar should contain single button "Next" that will move the app to the next page. This page will list processing blocks. For now let it just list "Count Unique Elements""

Refined by the author: "when there is no source, Next button is disabled; when there is only one source, it's selected by default. If more than one source, selection is possible with a simple highlight. Then block selection page should display a header to show currently selected source."

## Clarifications

### Session 2026-08-16

- Q: How does a person choose a source, given each source row is a card that already contains a Refresh button? → A: Tapping anywhere on the card except the Refresh button chooses it; the chosen card is shown by a border/tint **and** a checkmark.
- Q: Does the chosen source survive an app relaunch? → A: No — session-only, held in memory; a fresh launch re-applies the choice rules.
- Q: What does the processing blocks page header show about the chosen source? → A: Its name only — no record count, sync status, or dates.
- Q: With several sources known, is one chosen for the person? → A: No — nothing is pre-chosen and **Next** stays unavailable until they pick a card.
- Q: What does the start screen show when no sources are known? → A: A short empty-state message in place of the list, explaining there are no sources, with **Next** disabled.
- Q: Before the first result arrives, does the start screen show the no-sources message? → A: No — three distinct states: a loading indication first, then either the list or the no-sources message; the message never appears while still loading.
- Q: Can a source with no records or no sync history be chosen and carried forward? → A: Yes — any known source is choosable; data readiness is not this feature's concern.
- Q: Does returning from the processing blocks page re-load the sources list? → A: Yes — the same load runs as on first appearance; the populated list stays on screen while it runs, and FR-016 governs the chosen source.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Move forward with the only source (Priority: P1)

A person opens the app and sees the lottery sources. A bar is pinned to the bottom of the
screen, below where the source list ends, holding a single **Next** button. When exactly one
source is known, that source is already chosen for them and **Next** is ready to use — one
tap takes them to the processing blocks page. When no sources are known at all, **Next** is
visibly unavailable and a short message explains that there are no sources, so the screen
never reads as broken.

**Why this priority**: This is the whole forward path in its simplest form. It turns the
start screen from a dead end into the first step of a flow, and it covers the common case
(a single known source) with zero extra interaction.

**Independent Test**: Can be fully tested by running the app with exactly one source and
confirming that source shows as chosen and **Next** works, then with no sources and
confirming **Next** is unavailable. Delivers a complete usable path on its own.

**Acceptance Scenarios**:

1. **Given** the start screen is showing, **When** the person looks at the bottom of the
   screen, **Then** a bar is visible there containing a single button labelled "Next".
2. **Given** the app has not yet produced a result, **When** the start screen is showing,
   **Then** a loading indication stands in place of the list, the no-sources message is not
   shown, and **Next** is unavailable.
3. **Given** a result has arrived carrying no sources, **When** the start screen is showing,
   **Then** **Next** is unavailable and cannot be activated, and a short message stands in
   place of the list saying there are no sources.
4. **Given** exactly one source is known, **When** the start screen is showing, **Then**
   that source is shown as the chosen one and **Next** is available.
5. **Given** exactly one source is known and chosen, **When** the person taps **Next**,
   **Then** the app moves forward to the processing blocks page.
6. **Given** the source list is long enough to scroll, **When** the person scrolls to the
   very end of the list, **Then** the bottom bar remains visible and no source row is
   hidden behind it.
7. **Given** a source is chosen, **When** the person taps **Next** twice in rapid
   succession, **Then** the app moves forward exactly once.

---

### User Story 2 - Pick which source to work with (Priority: P2)

When several sources are known, none of them is chosen for the person. They pick one by
tapping anywhere on its card; the card takes on a highlight — a border or tint plus a
checkmark — so it is obvious which source is chosen. Only one source can be chosen at a
time — tapping a different card moves the highlight. Tapping the card's Refresh button
still just refreshes, and never changes the choice. **Next** stays unavailable until a
source has been picked.

**Why this priority**: It generalises P1 to the multi-source case. It is separable because
the single-source path in P1 is already a complete, shippable flow.

**Independent Test**: Can be fully tested by running the app with several sources,
confirming **Next** starts unavailable, tapping one row, seeing it highlighted and **Next**
become available, then tapping another row and seeing the highlight move.

**Acceptance Scenarios**:

1. **Given** more than one source is known, **When** the start screen first appears,
   **Then** no source is highlighted and **Next** is unavailable.
2. **Given** more than one source is known and none is chosen, **When** the person taps
   anywhere on a source card, **Then** that card becomes highlighted with a border or tint
   and a checkmark, and **Next** becomes available.
3. **Given** a source is chosen, **When** the person taps a different source card, **Then**
   the highlight moves to the newly tapped card and the previous card is no longer
   highlighted.
4. **Given** a source is chosen, **When** the person taps that same card again, **Then** it
   stays chosen and **Next** stays available.
5. **Given** a source is chosen, **When** the person taps the Refresh button on a different
   card, **Then** that source refreshes and the choice does not move.
6. **Given** a source is chosen, **When** the person taps **Next**, **Then** the app moves
   forward carrying that source as the chosen one.

---

### User Story 3 - See which source the blocks apply to (Priority: P3)

On the processing blocks page, a header at the top names the source the person chose, so
they never lose track of what the processing would apply to. Below it, the page lists the
processing blocks the app offers — at this stage a single entry, **Count Unique Elements**.

**Why this priority**: The header is what makes the destination page unambiguous once more
than one source exists. The list itself is the page's payload, but both are verifiable only
after a forward move works, so this comes after P1.

**Independent Test**: Can be fully tested by choosing a known source, moving forward, and
confirming the header names that source and the list contains "Count Unique Elements".

**Acceptance Scenarios**:

1. **Given** the person moved forward with a chosen source, **When** the processing blocks
   page appears, **Then** a header at the top of the page identifies that source by name.
2. **Given** the person moved forward with a different source than last time, **When** the
   processing blocks page appears, **Then** the header names the source chosen this time.
3. **Given** the processing blocks page is showing, **When** the person reads the list,
   **Then** it contains exactly one entry, labelled "Count Unique Elements".
4. **Given** the processing blocks page is showing, **When** the person looks at the page,
   **Then** it is identifiable as the processing blocks step of the flow.

---

### User Story 4 - Return to the sources list without losing the choice (Priority: P4)

After looking at the processing blocks, the person goes back to the sources screen and finds
it as they left it — the same sources, the same sync information, and the same source still
chosen and highlighted, so tapping **Next** again takes them straight back.

**Why this priority**: Expected behaviour rather than new capability, but a return that
cleared the choice would force the person to re-pick every time. Last because the forward
flow is usable without it.

**Independent Test**: Can be fully tested by choosing a source, moving forward, going back,
and confirming the same source is still highlighted and **Next** still available.

**Acceptance Scenarios**:

1. **Given** the processing blocks page is showing, **When** the person goes back, **Then**
   the sources list reappears with its bottom bar and **Next** button.
2. **Given** the person returns to the sources list, **When** the screen appears, **Then**
   the previously chosen source is still highlighted and the sources' sync information is
   unchanged.
3. **Given** the person returns to the sources list, **When** the screen re-loads its
   sources, **Then** the populated list stays on screen throughout — no loading indication
   replaces it — and the chosen source is still chosen once the result arrives.
4. **Given** the person has returned to the sources list, **When** they tap **Next** again,
   **Then** the processing blocks page is shown again with the same source in its header.

---

### Edge Cases

- **No sources at all**: the bar and **Next** are still shown, but **Next** is unavailable
  and clearly looks unavailable rather than silently doing nothing when tapped, and a short
  message stands in place of the list explaining that there are no sources.
- **Sources still loading**: the screen opens before any result arrives, so it shows a
  loading indication — not the no-sources message — and **Next** starts unavailable. When
  exactly one source arrives it becomes chosen and **Next** turns available without further
  interaction; when a result arrives carrying none, the loading indication gives way to the
  no-sources message.
- **The list reloads while a source is chosen**: if the chosen source is still present, it
  stays chosen and highlighted; if it has disappeared from the list, the choice is dropped
  and **Next** becomes unavailable again.
- **The list shrinks to a single source**: that remaining source becomes the chosen one
  automatically, matching the single-source rule.
- **The list grows from one source to several**: the already-chosen source stays chosen; the
  person is not forced to pick again.
- **A source is mid-refresh**: it can still be chosen, and choosing it neither cancels nor
  disturbs the refresh. Moving forward while a refresh is running does not cancel it.
- **A chosen source fails to sync**: the failure alert behaves as it does today, and the
  source stays chosen — a sync failure does not clear the choice.
- **A source that has never synced**: it shows "N/A" records and "Not synced" as it does
  today, and is still choosable and still able to move forward. If it is the only known
  source it is auto-chosen, so a first-run person is never blocked behind an unavailable
  **Next** they cannot explain.
- **Colour-blind or high-contrast use**: the highlight is perceivable without relying on
  colour alone.
- **Very long source name**: the header on the processing blocks page handles it gracefully
  rather than clipping mid-word or pushing content off-screen.
- **Large accessibility text sizes**: the **Next** label and the header grow with the
  person's chosen text size; the bar grows to fit and nothing is clipped.
- **Repeated forward/back cycles**: moving forward and back several times leaves a single
  sources screen and a single processing blocks page — no stack of duplicates builds up.

## Requirements *(mandatory)*

### Functional Requirements

#### Bottom bar

- **FR-001**: The start screen MUST present a bar fixed to the bottom of the screen, below
  the end of the source list, that stays in place while the list scrolls.
- **FR-002**: The bottom bar MUST contain exactly one action, a button labelled "Next".
- **FR-003**: The bottom bar MUST be visible whenever the start screen is shown, regardless
  of how many sources the list holds — including zero.
- **FR-004**: The source list MUST remain fully readable alongside the bar: the last row
  MUST be able to be brought completely into view rather than sitting underneath the bar.
- **FR-005**: The start screen MUST distinguish three states in place of the list: loading
  (no result has arrived yet), no sources (a result arrived and held none), and populated.
- **FR-006**: While loading, the start screen MUST show a loading indication and MUST NOT
  show the no-sources message. The no-sources message MUST appear only after a result has
  arrived carrying no sources, so the person is never told there are none while the app is
  still finding out.

#### Choosing a source

- **FR-007**: At most one source MUST be chosen at any time.
- **FR-008**: When no sources are known, no source MUST be chosen.
- **FR-009**: When exactly one source is known, that source MUST be chosen automatically,
  without the person acting.
- **FR-010**: When more than one source is known and none has been chosen yet, no source
  MUST be chosen automatically.
- **FR-011**: The person MUST be able to choose a source by tapping anywhere on its card.
- **FR-012**: The card's Refresh control MUST keep its existing behaviour: tapping Refresh
  MUST start a refresh and MUST NOT change which source is chosen.
- **FR-013**: Activating a card that is already chosen MUST leave it chosen.
- **FR-014**: Activating a different card MUST move the choice to it and clear the previous
  one.
- **FR-015**: The chosen source's card MUST be visually distinguished from the others by
  both a border or tint **and** a checkmark, so the distinction never depends on colour
  alone.
- **FR-016**: When the source list is reloaded, a chosen source that is still present MUST
  stay chosen; a chosen source that is no longer present MUST cease to be chosen.
- **FR-017**: Choosing a source MUST NOT affect that source's sync state, in-flight refresh,
  or failure alert.
- **FR-018**: The chosen source MUST NOT be stored between app launches. A fresh launch MUST
  start with no stored choice and re-apply FR-008 to FR-010.
- **FR-019**: Every known source MUST be choosable regardless of its record count, sync
  state, or sync history. A source that has never synced and holds no records MUST be
  choosable, MUST be auto-chosen when it is the only one, and MUST be able to move forward.

#### Moving forward

- **FR-020**: **Next** MUST be available when a source is chosen, and unavailable when none
  is chosen.
- **FR-021**: An unavailable **Next** MUST be visibly unavailable, and activating it MUST do
  nothing.
- **FR-022**: Activating an available **Next** MUST move the app forward to the processing
  blocks page, carrying the chosen source with it.
- **FR-023**: Activating **Next** more than once in quick succession MUST result in exactly
  one forward move.

#### Processing blocks page

- **FR-024**: The processing blocks page MUST present a header identifying the chosen source
  by its name, and MUST NOT show any other source detail there — no record count, no sync
  status, no dates.
- **FR-025**: The processing blocks page MUST present a list of the processing blocks the
  app offers.
- **FR-026**: The processing blocks list MUST contain exactly one entry at this stage,
  labelled "Count Unique Elements".
- **FR-027**: The processing blocks page MUST be identifiable as the processing blocks step
  of the flow.

#### Going back

- **FR-028**: The person MUST be able to go back from the processing blocks page to the
  sources screen using the platform's standard back gesture and control.
- **FR-029**: Returning to the sources screen MUST show the sources and sync information
  that were already loaded, without discarding them, and MUST keep the chosen source chosen
  and highlighted.
- **FR-030**: Returning to the sources screen MUST start the same load that runs when the
  screen first appears. The already-populated list MUST stay on screen while that load runs
  — the loading indication of FR-006 applies only before the first result of a screen's
  life — and the reload MUST be governed by FR-016 with respect to the chosen source.
- **FR-031**: The processing blocks page MUST be reachable repeatedly — going back and
  tapping **Next** again MUST show it again.

#### Accessibility

- **FR-032**: The **Next** button, each source card as a choosable element, the card's
  Refresh button as a separate control, the empty-state message, the header, and each
  processing block entry MUST be reachable and operable with assistive technology, and MUST
  be announced by their visible labels.
- **FR-033**: Assistive technology MUST be able to convey which source is chosen and whether
  **Next** is currently available.

### Key Entities *(include if feature involves data)*

- **Chosen source**: which one of the known sources the person is working with. At most one
  at a time; may be none. Derived automatically when exactly one source is known, otherwise
  set by the person. It gates whether the flow can move forward and is what the processing
  blocks page's header names.
- **Processing Block (catalogue entry)**: one kind of processing the app can apply to
  lottery data, identified by a stable identity and presented by a human-readable name. The
  only entry at this stage is "Count Unique Elements". Entries are fixed, app-provided
  content — not user-created and not fetched from a remote service.
- **Processing Blocks Page**: the step of the flow that presents the catalogue of processing
  blocks for the chosen source. Beyond the source it was given and the list it presents, it
  holds no state of its own at this stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With exactly one source known, a person reaches the processing blocks page in
  a single tap, with no selection step.
- **SC-002**: With several sources known, a person reaches the processing blocks page in
  exactly two taps — choose, then **Next**.
- **SC-003**: A person can tell which source is chosen, and which source the processing
  blocks page refers to, without scrolling on any supported screen size, at every supported
  text size, in both light and dark appearance.
- **SC-004**: **Next** is never activatable while no source is chosen — 0 occurrences of the
  flow moving forward without a chosen source.
- **SC-005**: 100% of source rows can be scrolled fully into view; no row is permanently
  obscured by the bottom bar.
- **SC-006**: The processing blocks page is fully presented within 1 second of the tap, with
  no loading indicator at any point, because it presents fixed content.
- **SC-007**: Going back and forward five times in a row leaves the app in the same state as
  a single forward move — same chosen source, no duplicated screens, no reset of the sources
  list.
- **SC-008**: Every element added by this feature is reachable and correctly announced by
  assistive technology, including the chosen state of a source and the availability of
  **Next**.
- **SC-009**: A person who opens the app with no sources is told in words why they cannot
  continue — 0 states in this feature present an unavailable **Next** over a blank screen,
  and 0 occurrences of the no-sources message being shown before a result has arrived.

## Assumptions

- **With several sources, nothing is pre-chosen** (confirmed in Clarifications, see FR-010),
  so the person must pick before **Next** becomes available. Pre-choosing the first card, or
  the most recently synced one, was considered and rejected: it would silently decide which
  data set the analysis runs against.
- **The choice is single, not multiple.** "It's selected" and "a simple highlight" are read
  as one-at-a-time selection. Choosing several sources to process together is not in scope.
- **Choosing cannot be undone by re-tapping.** Tapping the chosen row again keeps it chosen
  rather than clearing it, so the person cannot accidentally strand themselves with an
  unavailable **Next**.
- **The choice lives for the session** (confirmed in Clarifications, see FR-018). It is held
  in memory while the app runs and never written to storage, so no new storage contract is
  needed.
- **Blocks are display-only.** "For now let it just list" is read as: entries are presented
  but not yet selectable, configurable, or runnable. Tapping an entry does nothing at this
  stage; running a block and showing its results are separate future features.
- **The catalogue is hard-coded content, not data.** The single entry is app-provided; no
  fetching, persistence, or remote configuration is involved.
- **"Count Unique Elements"** refers to the count block described in the project's target
  domain model — producing, per element, the number of times it occurs — but this feature
  only *names* it in a list; no counting behaviour is specified or built here.
- **The header names the source and nothing more** (confirmed in Clarifications, see
  FR-024), matching the name already shown on its card. Because it carries no sync or record
  detail, it needs no refresh behaviour of its own while the page is open.
- **Forward movement is a push onto the existing screen flow**, so the platform's standard
  back affordance applies and no bespoke back control is specified.
- **The bar holds one action deliberately.** No secondary action (back, cancel, settings) is
  added to it; the bar is expected to grow later as the flow does.
- **Existing sources behaviour is untouched.** Loading, refreshing, sync severity, and
  failure alerts on the start screen keep working exactly as they do today; this feature
  adds the choosable highlight and the bar beneath them.

## Out of Scope

- Choosing more than one source at a time.
- Persisting the chosen source across app launches.
- Executing any processing block, or displaying counts, results, or derived data.
- Configuring a block's parameters, ordering blocks, or composing them into a pipeline.
- Any processing block beyond the single "Count Unique Elements" entry.
- Any action on the processing blocks page other than going back.
- A further "next" step beyond the processing blocks page.
