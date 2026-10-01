# Feature Specification: Missing Records Estimate

**Feature Branch**: `009-missing-records-estimate`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "LTA-4 — Estimate missing records from last two weeks. Use the last two full weeks of draws to learn a source's draw cadence and estimate how many records are missing since the latest stored record. Severity: the estimate replaces the day-based rule — 0 missing is green, 1 is yellow, 2 or more is red; without enough history the existing day-based rule applies unchanged; a never-synced source stays 'not synced'. Window: the two full Monday–Sunday weeks before the week that holds the latest stored draw; 'not enough history' means stored draws don't reach back to the start of that window, or the window holds no draws. Formula: rate = draws in the window ÷ 14; missing = floor(rate × days from the latest record to now), days fractional. Card: a '~N missing' line next to Latest Record, hidden when N is 0 or when there's no estimate. The source carries only the cadence; the start page computes missing and severity from it, the latest record and the injected clock. Weeks use a Gregorian calendar with Monday first, injected for deterministic tests. Tests first; light/dark previews for each severity with and without an estimate."

## Clarifications

### Session 2026-10-01

- Q: Where should a source's cadence be worked out and kept? → A: Once after each successful sync, stored with the source's metadata (like the spec 005 skipped count). Metadata saved before this feature has no cadence, so that source shows no estimate until its next successful sync.
- Q: Which time zone defines the Monday–Sunday weeks? → A: UTC, the zone the draws are dated in (Gregorian, Monday first).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See how many draws a source is probably missing (Priority: P1)

A person opens the start page. For each source that has enough history, the card works out how often that source normally publishes draws, from the two full weeks before its latest stored draw. It then estimates how many draws should have appeared since that latest draw, and shows "~N missing" next to the Latest Record date. The person can tell at a glance whether the stored history is current, instead of guessing from the date of the last sync.

**Why this priority**: This is the information the ticket adds. The date of the last sync says when the app last asked, not whether the data is complete. A source synced yesterday can still lack a week of draws if the source published late, and a source synced a week ago can be complete if it publishes rarely.

**Independent Test**: Give a source a stored history with a regular cadence, for example 3 draws a week for the last month, and a latest draw several days ago. Open the start page. The card shows the expected "~N missing" next to Latest Record. With no gap, no line is shown.

**Acceptance Scenarios**:

1. **Given** a source that published 6 draws in the two full weeks before the week of its latest draw (rate 6 ÷ 14 per day), with that latest draw 7 days before now, **When** the card renders, **Then** it shows "~3 missing" next to Latest Record (⌊6/14 × 7⌋ = 3).
2. **Given** the same source with its latest draw 1 day before now, **When** the card renders, **Then** no missing line is shown (⌊6/14 × 1⌋ = 0).
3. **Given** a source whose estimate is exactly 1, **When** the card renders, **Then** it shows "~1 missing".
4. **Given** a source whose stored draws don't reach back to the start of the two-week window, **When** the card renders, **Then** no missing line is shown.
5. **Given** a source whose two-week window holds no draws at all, **When** the card renders, **Then** no missing line is shown.
6. **Given** a source that has never synced, **When** the card renders, **Then** no missing line is shown.
7. **Given** the compact card (narrow screens, spec 007), **When** it is expanded, **Then** the missing line appears next to Latest Record in its details, as on the full card.

---

### User Story 2 - The severity colour follows the estimate (Priority: P1)

The coloured sync badge, and the dot on the compact card, now reflect how much data is probably missing rather than how long ago the app synced: green when nothing is missing, yellow when one draw is, red when two or more are. A source without enough history to estimate keeps today's day-based colours, so no card loses its colour.

**Why this priority**: The colour is the first thing a person reads on the card. Keeping it on the old day-based rule while the line beside it says "~3 missing" would contradict the estimate. It ships with Story 1.

**Independent Test**: For one source with enough history, vary how long ago its latest draw was so the estimate is 0, 1 and 3. The badge is green, yellow and red. For a source without enough history, vary the time since its last sync. The badge follows today's thresholds (green under 2 days, yellow under 4, red from 4).

**Acceptance Scenarios**:

1. **Given** a source with an estimate of 0 missing, **When** the card renders, **Then** the badge is green, however long ago the last sync was.
2. **Given** a source with an estimate of exactly 1 missing, **When** the card renders, **Then** the badge is yellow.
3. **Given** a source with an estimate of 2 or more missing, **When** the card renders, **Then** the badge is red, even if it synced minutes ago.
4. **Given** a source without enough history, **When** the card renders, **Then** the badge follows today's day-based rule, unchanged.
5. **Given** a source that has never synced, **When** the card renders, **Then** it stays "not synced" (grey).
6. **Given** a sync that brings in the missing draws, **When** the sync finishes, **Then** the estimate and the colour are recomputed from the new latest draw and history.

---

### User Story 3 - Read the estimate in every appearance (Priority: P3)

The missing line is legible in light and dark appearance and at every text size, wraps at word boundaries, and is announced by VoiceOver, on both card variants.

**Why this priority**: Both cards were already reworked for the largest text sizes (spec 007). The new line must not regress that. It is quality on top of Stories 1–2.

**Independent Test**: Render both cards with a missing line in light and dark at the default and the largest accessibility text size. The line wraps at word boundaries and the layout reflows as before. VoiceOver reads it.

**Acceptance Scenarios**:

1. **Given** a card with a missing line, **When** it is shown at the largest accessibility text size, **Then** the line wraps at word boundaries and the card's existing reflow is unchanged.
2. **Given** a card with a missing line, **When** VoiceOver reads the Latest Record, **Then** it announces the estimate in words (for example "about 3 missing").
3. **Given** a card with a missing line in light or dark appearance, **When** it renders, **Then** the line is distinguishable from the date without relying on colour alone.

---

### Edge Cases

- **Latest draw in the current week**: the window is still the two full weeks *before* that week, so a source synced today is measured on settled weeks, not on a partial one.
- **Source left unsynced for weeks**: the window is anchored on the latest stored draw, not on today, so it still holds data and an estimate is made. That estimate grows with the gap.
- **History that starts inside the window**: not enough history. No estimate, and the day-based severity applies.
- **Window with draws but a low rate** (for example 1 draw in 14 days): the estimate stays 0 until about 14 days have passed since the latest draw. That is expected for a rare draw.
- **Clock before the latest draw** (device clock wrong): the interval is treated as 0, so nothing is missing and the colour is green.
- **Very large gaps**: the estimate is shown in full, with the locale's number grouping (for example "~1,204 missing").
- **Draw days and time zones**: draws are dated at midnight UTC, so the weeks are Monday–Sunday in UTC. A device in another time zone sees the same estimate.
- **Metadata from before this feature**: it has no cadence, so the card shows no estimate and uses the day-based colour until the next successful sync stores one.
- **Estimate is approximate**: just after a sync, a source that draws a few times a week can show "~1 missing" before its next draw is due. The "~" signals that this is an estimate, and the decision accepts it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST derive, for each source with stored draws, its cadence: the number of stored draws dated within the two full Monday–Sunday weeks before the week that holds the latest stored draw, divided by 14, in draws per day.
- **FR-002**: The system MUST treat the cadence as unavailable when the earliest stored draw is later than the start of that window, or when the window holds no draws.
- **FR-003**: The cadence MUST be derived after every successful sync from the full stored set (after merging), MUST be persisted with the source's metadata so it survives a relaunch, and MUST be available whenever the start page lists the sources without reading the stored draws. A failed sync MUST leave the stored cadence unchanged. Metadata written before this feature MUST still load, with no cadence.
- **FR-004**: The start page MUST estimate the missing records as ⌊cadence × days from the latest stored draw to now⌋, with days as a fractional interval taken from the app's injected clock, and a negative interval treated as 0.
- **FR-005**: When an estimate is available, the sync severity MUST be green for 0 missing, yellow for 1, and red for 2 or more, replacing the day-based rule for that source.
- **FR-006**: When no estimate is available, the sync severity MUST follow the existing day-based rule unchanged. A never-synced source MUST stay "not synced".
- **FR-007**: Both card variants MUST show a "~N missing" line next to the Latest Record date when the estimate is greater than 0. The line MUST be hidden when the estimate is 0 or unavailable.
- **FR-008**: The missing line MUST use the locale's number grouping, MUST be announced by assistive technologies with its meaning in words, MUST wrap at word boundaries at every text size, and MUST follow the app's design tokens in light and dark appearance.
- **FR-009**: The estimate and the severity MUST be recomputed when the source list loads and when a sync finishes, both from the injected clock.
- **FR-010**: Weeks MUST be computed with a Gregorian calendar in UTC (the zone the draws are dated in) that starts on Monday, and that calendar MUST be replaceable in tests.

### Key Entities *(include if feature involves data)*

- **Source**: a lottery data source as the app presents it. Gains its cadence (draws per day), which is absent when there isn't enough history.
- **Source metadata**: the persisted per-source sync analytics. Gains the cadence derived at the last successful sync.
- **Cadence window**: the two full Monday–Sunday weeks before the week holding a source's latest stored draw. It is the sample the cadence is measured on.
- **Missing estimate**: ⌊cadence × days since the latest draw⌋. It is shown on the cards and decides the severity colour. It is never stored, because it changes as time passes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a reference history with a known cadence, the estimate shown matches the hand-computed value in 100% of the covered cases (0, 1 and many missing, plus each "not enough history" case).
- **SC-002**: A source with 2 or more estimated missing draws is never shown green, and a source with 0 is never shown yellow or red.
- **SC-003**: Sources without enough history show exactly the same colour as before this feature, for every time-since-sync threshold.
- **SC-004**: Opening the start page shows the estimate with no noticeable delay compared with today (the list appears as fast as before for the existing source with about 7,400 draws).
- **SC-005**: At the largest accessibility text size, cards with the missing line show no mid-word breaks, in both light and dark appearance.

## Assumptions

- "Next to Latest Record" means directly under the Latest Record date, in the same detail block, on both the full card and the compact card's details.
- The missing line reads "~N missing", localised through the app's string resources, and has no singular/plural wording change ("~1 missing").
- The estimate is informational only: it doesn't trigger a sync and has no tap action.
- Severity is recomputed only when the list loads or a sync finishes, as today. The estimate doesn't tick live while the page stays open.
- Only MBNet exists as a source today. The rule applies to every source, since each one's cadence comes from its own stored draws.
- The skipped-records note (spec 005) and the Fetch/Refresh wording (spec 008) are unchanged.
