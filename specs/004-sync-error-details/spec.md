# Feature Specification: Specific Sync Errors

**Feature Branch**: `004-sync-error-details`

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "LTA-1 — Keep specific sync errors instead of one generic failure. Every repository failure is currently collapsed into one generic error, and the repository itself has only one fetch failure case, so the UI cannot tell a network failure from an unsupported source, an undecodable body, a format change or a local store failure. Define a Domain error set that carries these cases, map the source and store errors onto it, pass it through the business logic, and let the source card show a matching alert message. Ship with reducer and repository tests for each case."

## Clarifications

### Session 2026-09-30

- Q: Should a failed sync stay visible on the source card after the alert is dismissed? → A: No — the alert is the only surface; dismissing it clears the failure.
- Q: Should every error status from the server get the same "try again later" message? → A: No — 5xx statuses say "try again later"; 4xx statuses say the source's address may have changed and retrying won't help until the app is updated. Both show the status code.
- Q: Does a connection dropped mid-sync, or a server name that can't be looked up, count as offline or as server unreachable? → A: Server unreachable. Offline is only when the device reports no connection at all, cellular data is off, or roaming is off.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Understand why a sync failed (Priority: P1)

A person taps Refresh on a source card and the sync fails. Instead of the same "Couldn't refresh this source. Check your connection and try again." message for every failure, the alert tells them what went wrong in plain words — they are offline, the source's server couldn't be reached, the server answered with an error, the source's data format changed, the source is no longer available, or the downloaded draws couldn't be saved on the device — so they know whether to check their connection, wait and try later, or stop retrying.

**Why this priority**: This is the whole point of the ticket. Today the only guidance is "check your connection", which is wrong for most failure kinds: a format change or a full disk will never be fixed by reconnecting, and the user retries forever.

**Independent Test**: Force each failure kind in turn (offline device, unreachable server, error status, changed data format, missing source, failed save) and tap Refresh; each time the alert names that cause and the card keeps its previous analytics.

**Acceptance Scenarios**:

1. **Given** the device has no network connection, **When** the user refreshes a source, **Then** the alert says the device appears to be offline and asks them to check their connection.
2. **Given** the source's server cannot be reached or does not answer in time, **When** the user refreshes, **Then** the alert says the source's server couldn't be reached and suggests trying again later.
3. **Given** the server answers with a server-side error status (500 or above), **When** the user refreshes, **Then** the alert says the server reported a problem, shows the status code, and suggests trying again later.
4. **Given** the server answers with a request error status (400–499, for example "not found"), **When** the user refreshes, **Then** the alert shows the status code, says the source's address may have changed, and that retrying won't help until the app is updated.
5. **Given** the server's response can't be read as text, or none of its rows can be read as draws, **When** the user refreshes, **Then** the alert says the source's data format isn't recognised and that retrying won't help until the app is updated.
6. **Given** the card refers to a source the app no longer knows, **When** the user refreshes, **Then** the alert says the source is no longer available.
7. **Given** the draws download fine but can't be saved on the device, **When** the user refreshes, **Then** the alert says the draws couldn't be saved on this device and suggests freeing up space.
8. **Given** a failure of any kind, **When** the user dismisses the alert, **Then** the card returns to idle with its previous analytics unchanged and its stored draws untouched.

---

### User Story 2 - Understand why a chain couldn't run (Priority: P2)

A person runs a chain and the source's stored draws can't be read. The alert says whether the source is no longer available or its stored draws are damaged, instead of one message for both.

**Why this priority**: The same generic collapse happens on the run path, which reads the source's stored draws. It is less frequent than sync failures and has only two causes, so it comes second.

**Independent Test**: Run a chain on a source the app no longer knows, then on a source whose stored draws break its combination shape; each run shows its own message and produces no results.

**Acceptance Scenarios**:

1. **Given** a chain's source is no longer known to the app, **When** the user runs the chain, **Then** the alert says the source is no longer available and no results are produced.
2. **Given** a stored draw of the chain's source doesn't fit the source's game, **When** the user runs the chain, **Then** the alert says the source's stored draws couldn't be read and suggests refreshing the source.

---

### Edge Cases

- **Timeout, dropped connection, unknown host**: a request that runs out of time, a connection that drops mid-download, and a server name that can't be looked up all count as "server couldn't be reached", not as offline.
- **Cancelled sync**: a sync that is cancelled (for example, superseded by a new refresh or the screen closing) shows no alert at all.
- **Empty body**: a response with no rows at all is still a successful sync with an empty history (unchanged behaviour); only a response whose rows are all unreadable is a format change.
- **Partly malformed body**: some unreadable rows among good ones is still a success (unchanged behaviour; surfacing the skipped count is LTA-2).
- **Saved but not read back**: if the draws were saved but the updated source details can't be read back afterwards, the failure is reported as a save failure.
- **Unrecognised failure**: anything that fits none of the kinds above shows a general "couldn't refresh this source, try again" message, so no failure ever goes unreported.
- **Alert already showing**: a failure alert that hasn't been dismissed yet survives a reload of the source list (unchanged behaviour) and keeps its specific message.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST classify every failed sync as exactly one of: offline, server unreachable, server error (with its status code), unreadable data format, source unavailable, storage failure, or unknown.
- **FR-002**: The failure kind MUST be kept from the point where the failure happens up to the source card; no layer may replace it with a more general failure.
- **FR-003**: On a failed sync, the source card's alert MUST show a message specific to the failure kind, as described in User Story 1. The alert title stays "Sync failed".
- **FR-004**: The server-error message MUST include the status code the server returned, and MUST differ by status range: 500 and above suggests trying again later; 400–499 says the source's address may have changed and retrying won't help until the app is updated. Any other non-success status is treated like 400–499.
- **FR-005**: Messages MUST name the source by its display name where the sentence refers to it (for example, "Couldn't reach MBNet Server.").
- **FR-006**: A failed sync of any kind MUST leave the source's stored draws and its card analytics exactly as they were (unchanged from spec 001 FR-006 / FR-021).
- **FR-007**: A cancelled sync MUST NOT show an alert.
- **FR-008**: A chain run whose source draws can't be read MUST say whether the source is unavailable or its stored draws are unreadable, as described in User Story 2.
- **FR-009**: The technical detail of each failure MUST still be written to the app's diagnostic log, as it is today; the user-facing messages MUST NOT show raw technical error text.
- **FR-010**: Every failure kind in FR-001 and FR-008 MUST be covered by an automated test at the layer that detects it and at the screen that shows it.

### Key Entities

- **Sync failure**: why a source's sync failed — one of the kinds in FR-001. The server-error kind carries the status code. It is part of the core rules, so the source card and the business logic depend on it without knowing about networking or storage. It also marks a cancelled sync, which is not a failure and is never shown (FR-007).
- **Read failure**: why a source's stored draws couldn't be read for a run — source unavailable or stored draws unreadable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each of the 7 sync failure kinds produces its own alert message, and the server-error kind has two (5xx and 4xx); no two of these 8 messages are the same.
- **SC-002**: 100% of failed syncs show an alert, except cancelled ones, which show none.
- **SC-003**: After any failed sync, the source's stored draws and card analytics are identical to before the attempt.
- **SC-004**: Both run failure kinds produce distinct alert messages.
- **SC-005**: Every failure kind has at least one automated test where it is detected and one where its message is shown, and the full test suite passes.

## Assumptions

- The alert stays a single-button (dismiss) alert; adding a Retry button is out of scope.
- The alert is the only place a failure shows: the card gains no persistent failure indicator, and dismissing the alert clears the failure.
- "Offline" means the device reports it has no network connection, cellular data is turned off, or roaming is turned off; every other transport failure (timeout, dropped connection, unknown host, refused connection) counts as "server unreachable".
- The message copy in User Story 1 is the intent; the exact wording is settled in implementation and kept as named copy tokens.
- MBNet is the only source today; the classification is written so that every future source reports the same failure kinds.
- Showing how many malformed rows were skipped belongs to LTA-2 and is out of scope here.
- Previously stored data, the retry behaviour and the refresh-in-progress guard from spec 001 are unchanged.
