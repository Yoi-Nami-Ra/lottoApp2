# Feature Specification: Processing Block Pipeline

**Feature Branch**: `003-block-pipeline`

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "LTA-8" — spec the processing-block pipeline: the data that flows between
blocks, each block's input and output, and how chains are represented and executed, turning the
processing-block catalogue (today a single display-only "Count Unique Elements" entry) into blocks a
person can chain together and run against a source's draw history.

Decisions carried in from the ticket refinement of LTA-6, LTA-8, LTA-9, LTA-10, LTA-18, LTA-19, LTA-20
and LTA-27 are recorded under Clarifications.

## Clarifications

### Session 2026-09-28/29 (ticket refinement)

- Q: What is a combination for the purposes of every block? → A: A combination without repetition in
  which order does not matter — {1, 5, 9} and {9, 1, 5} are the same combination.
- Q: Can one collection mix combination shapes? → A: No — a collection holds combinations of x
  elements drawn from a pool of y, with x and y the same for every entry.
- Q: What kinds of data flow between blocks? → A: Three: a **draw collection** (a source's entries or
  a filtered/sorted subset of them), a **count result** (pairs of a unique item and how many times it
  occurs), and a **single number**.
- Q: Can count results feed further blocks? → A: Yes — sort by count and every filter also accept a
  count result, so "sort by count, then keep the first 10" gives a top 10.
- Q: What shape can a chain have? → A: A tree: its root is the chain's input (the draws of whichever
  source it runs against), each block has exactly one input, and one block's output can feed several
  blocks.
- Q: Do sorts take a direction? → A: Yes, ascending or descending, on every sort.
- Q: How are ties ordered when sorting by count? → A: By item ascending, whatever the direction.
- Q: What happens when a filter asks for more than the collection holds? → A: It clamps: keeping the
  first/last x returns everything, skipping the first/last x returns nothing. x is 0 or more.
- Q: What does "count all elements" count? → A: Every drawn element across the entries — entries × x.
- Q: Does "count unique elements" include pool elements that were never drawn? → A: No — only
  elements that occur.
- Q: What is a sub-combination? → A: z of a combination's elements, 2 ≤ z < x, with the same "no
  repetition, order doesn't matter" rules; equal sub-combinations from different draws are equal.
- Q: When does a chain run? → A: On demand. Editing the chain after a run marks results out of date
  rather than re-running; a new run cancels one still in progress.
- Q: Is shared work recomputed per branch? → A: No — within a run each block is evaluated once and
  its output shared by all its children; nothing is kept between runs.
- Q: Are chains saved? → A: Superseded on 2026-09-29 — see that session.
- Q: How are results presented? → A: Each leaf shows a short summary and opens its own result screen.
  (Extended on 2026-09-29, analysis follow-up: every block that ran does the same.)

### Session 2026-09-29

- Q: Before any sort block, what order are a source's draws in? → A: Index ascending (oldest first), so "keep last 100" gives the newest 100.
- Q: Should results be marked out of date when their source is synced? → A: Chains are not tied to a
  source — the same chain can run against different sources. The output of any block (not only a
  leaf) can be saved; every result, saved or not, records the source and that source's data state it
  was computed from, and reads as out of date once that source's data has changed.
- Q: Should the chain itself also be saved across app launches? → A: Yes — chains are saved and
  listed; a person can reopen one and run it against any source.
- Q: Should runs meet hard speed targets? → A: No — no time limits; a run shows its progress and the
  app stays responsive throughout.
- Q: After a relaunch, does a saved chain still show its last run's results? → A: No — only
  explicitly saved results survive; a reopened chain reads "not run". Before unsaved results would be
  lost, the app warns and offers to save them (see also the draft answer below).
- Q: How does the person choose which source a run uses? → A: Always the source chosen on the start
  page; to use another, go back, choose it, and reopen the chain.
- Q: Where does the person find saved chains and saved results? → A: The Blocks page lists saved
  chains plus "New chain"; each chain lists the results saved from it.
- Q: What happens to a chain's saved results when the chain is deleted? → A: They are deleted with
  it, after a warning that names how many will go.
- Q: If a chain is edited after a result was saved from it, is that saved result out of date? → A:
  No — it shows "chain changed since" as information; its recorded path stays authoritative.
- Q: Are unsaved results kept automatically when the app goes to the background? → A: Yes, as a
  draft; the next time that chain is opened, the app offers to restore them.

### Session 2026-09-29 (analysis follow-up)

- Q: US7 said z = x is refused when set, but a chain isn't tied to a source — which holds? → A:
  FR-011: z = 1 is refused when set; z not less than x fails only that leaf when the chain runs
  against a source.
- Q: What does "going back from the blocks page" mean now that the blocks page lists chains? → A:
  Leaving the open chain. The blocks page is the list of saved chains; an open chain is "the chain".
- Q: Which moments trigger the unsaved-results warning? → A: Leaving the chain (which also covers
  opening another chain). Deleting a chain that has a draft says so in the delete warning, with no
  save option from the list.
- Q: Can an intermediate block's output be viewed, not only saved? → A: Yes — every block that ran
  shows a summary and opens its result view.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Count how often each number was drawn (Priority: P1)

A person has chosen a source on the start page and moved on to the processing blocks page. They
run **Count Unique Elements** against that source's full draw history and see, for every number
that has ever been drawn, how many times it came up.

**Why this priority**: It is the first result the app produces from stored data — the reason the
sources exist — and the single block already listed on the blocks page (spec 002). Every other
story extends this one.

**Independent Test**: With a source holding a known set of draws, run Count Unique Elements alone
and compare every element's count with a hand count of the same draws.

**Acceptance Scenarios**:

1. **Given** a source with 3 stored draws {1, 2, 3}, {2, 3, 4}, {3, 4, 5}, **When** the person runs
   Count Unique Elements, **Then** the result is 1→1, 2→2, 3→3, 4→2, 5→1 and nothing else.
2. **Given** a 6-of-49 source where the number 17 was never drawn, **When** the block runs, **Then**
   17 does not appear in the result.
3. **Given** a source with no stored draws, **When** the block runs, **Then** the result is empty and
   the person is told there is nothing to count, not shown an error.

---

### User Story 2 - Narrow the draws before counting (Priority: P2)

The person wants recent behaviour, not all-time totals. They put a filter in front of the count —
for example "keep the last 100 draws" — and the count covers only those draws.

**Why this priority**: All-time counts over decades of history hide recent trends; limiting the
window is the first thing a person does with a count. It introduces chaining (one block feeding
the next).

**Independent Test**: Build source → keep last 100 → Count Unique Elements, and check the counts
equal a hand count over the 100 most recent draws in the source's current order.

**Acceptance Scenarios**:

1. **Given** a source with 500 draws, **When** the person chains "keep the last 100" before the
   count, **Then** the counts cover exactly the last 100 draws.
2. **Given** a source with 50 draws, **When** the filter asks to keep the last 100, **Then** all 50
   draws are kept and the chain still runs.
3. **Given** a source with 50 draws, **When** the filter asks to skip the first 100, **Then** no
   draws remain and the count is empty.
4. **Given** "keep the first 0", **When** the chain runs, **Then** no draws remain.
5. **Given** a chain that sorts by date descending before "keep the first 10", **When** it runs,
   **Then** the ten newest draws are kept.

---

### User Story 3 - Rank and trim the counts (Priority: P3)

The person wants "the ten most frequent numbers". They sort the count result by count, descending,
then keep the first 10.

**Why this priority**: A raw count is a set with no order; ranking is what turns it into an answer.
It shows count results feeding further blocks.

**Independent Test**: Build source → Count Unique Elements → sort by count descending → keep first
10, and check the ten items and their order against a hand-ranked list, ties by item ascending.

**Acceptance Scenarios**:

1. **Given** counts 3→5, 7→5, 12→4, **When** sorted by count descending, **Then** the order is 3, 7,
   12 (equal counts fall back to item ascending).
2. **Given** the same counts, **When** sorted by count ascending, **Then** the order is 12, 3, 7 (the
   tie still falls back to item ascending).
3. **Given** a count result that was not sorted, **When** it is shown, **Then** it is presented in a
   fixed display order (by item ascending) without implying a ranking.

---

### User Story 4 - Compare branches side by side (Priority: P4)

The person wants to compare the last 50 draws with the last 100. From the same source they add two
branches — "keep the last 50 → count" and "keep the last 100 → count" — and run the whole chain once
to get both results.

**Why this priority**: Comparison is where the tree shape earns its keep, but every earlier story
works with a single straight chain.

**Independent Test**: Build a source with two branches, run once, and check both leaves produce
the same results as running each branch as its own straight chain.

**Acceptance Scenarios**:

1. **Given** a source with two filter branches each ending in a count, **When** the chain runs,
   **Then** both leaves produce a result from one run.
2. **Given** a block with two children, **When** the chain runs, **Then** that block is evaluated
   once and both children receive its output.
3. **Given** a chain with three leaves, **When** it runs, **Then** there are exactly three results,
   one per leaf, each reachable from its leaf.

---

### User Story 5 - Only sensible chains can be built (Priority: P5)

As the person adds blocks, the app only lets a block sit under a parent whose output it can use. Sort
by count cannot go directly under the source; sort by date cannot go under a count; nothing can go
under "count all elements".

**Why this priority**: It keeps every chain runnable, so a run never fails because of how the chain
was assembled. It matters once the catalogue holds more than one kind of block.

**Independent Test**: Try attaching every block kind under every parent kind and check that exactly
the combinations in the compatibility table (FR-010) are accepted.

**Acceptance Scenarios**:

1. **Given** the source, **When** the person tries to add "sort by count" directly under it,
   **Then** the block is refused with a reason naming what it needs (counts).
2. **Given** a Count Unique Elements block, **When** the person tries to add "sort by date" under
   it, **Then** it is refused with a reason naming what it needs (draws).
3. **Given** a "count all elements" block, **When** the person tries to add anything under it,
   **Then** it is refused — a single number ends a branch.
4. **Given** a refused attach, **When** the chain is inspected, **Then** it is unchanged.

---

### User Story 6 - Edit, re-run, and stop a long run (Priority: P6)

After a run the person changes a parameter — "last 100" becomes "last 50". The earlier results stay
visible but are marked out of date until they run again. If a run takes long, starting a new run
replaces it.

**Why this priority**: It makes iteration safe and honest about stale numbers; it only matters once
people run chains repeatedly.

**Independent Test**: Run a chain, change one parameter, check every result is marked out of date;
run again and check the marks clear and the results reflect the new parameter.

**Acceptance Scenarios**:

1. **Given** a chain that has run, **When** the person edits any block, adds one or removes one,
   **Then** the previous results are marked out of date and nothing re-runs by itself.
2. **Given** a leaf added after the last run, **When** the chain is shown, **Then** that leaf reads
   "not run" rather than showing a result.
3. **Given** a run in progress, **When** the person starts another run, **Then** the first run stops
   and only the second run's results appear.
4. **Given** results marked out of date, **When** the chain runs again, **Then** the marks clear.

---

### User Story 7 - Count repeated combinations and sub-combinations (Priority: P7)

Beyond single numbers, the person asks which whole draws have repeated ("Count Unique
Combinations") and which pairs or triples come up most often ("Count Unique Sub-combinations" of
size z).

**Why this priority**: These build directly on the same count result and sorting rules, so they
come after the element count is proven; they are the richer questions the pipeline was designed to
support.

**Independent Test**: With draws that contain one repeated combination (in a different order) and
a known shared pair, run each block and compare with a hand count.

**Acceptance Scenarios**:

1. **Given** draws {1, 5, 9, 20, 33, 41} and {41, 33, 20, 9, 5, 1}, **When** combinations are
   counted, **Then** that combination has count 2.
2. **Given** a combination drawn once, **When** combinations are counted, **Then** it has count 1.
3. **Given** z = 2 on 6-of-49 draws, **When** sub-combinations are counted, **Then** each draw
   contributes its 15 pairs, and a pair appearing in 3 draws has count 3.
4. **Given** z = 1, **When** the person sets it, **Then** the value is refused (z must be at least
   2). **Given** a z that is not less than x of the source a run uses, **When** the chain runs,
   **Then** only that leaf fails, naming the parameter — a chain is not tied to a source, so z < x
   can only be checked against the source of a run (FR-011).
5. **Given** a z whose work exceeds the limit in FR-022, **When** the chain runs, **Then** that leaf
   reports it was too large to compute and names the limit; other leaves still produce results.

---

### User Story 8 - Reuse a chain and keep its results (Priority: P8)

The person builds "last 100 → count → sort → top 10" once and runs it against MBNet, then against a
second source, without rebuilding it. Along the way they save the counts and the top 10 — any
block's output, not just the last one. Later, after MBNet syncs new draws, the saved MBNet results
say they are out of date.

**Why this priority**: It turns a one-off calculation into something a person can come back to, but
every earlier story is useful without it.

**Independent Test**: Run one chain against two sources, save an intermediate and a leaf result
from each, relaunch, sync one source, and check that only that source's saved results read as out of
date.

**Acceptance Scenarios**:

1. **Given** a chain built while source A was chosen, **When** the person goes back, chooses source B
   on the start page, reopens the chain and runs it, **Then** it runs unchanged and its results name
   source B.
2. **Given** a finished run, **When** the person saves the output of an intermediate block, **Then**
   the saved result holds that block's output and the path of blocks that produced it.
3. **Given** saved results and the chain that produced them, **When** the app is relaunched,
   **Then** both are still listed; the results can be opened and the chain reopened and run again.
4. **Given** a result saved from source A, **When** source A syncs new draws, **Then** that result
   reads as out of date, and results saved from source B do not.
5. **Given** a saved result, **When** the person deletes it, **Then** it is no longer listed.
6. **Given** a chain with unsaved results, **When** the person leaves the chain (goes back to the
   list of chains), **Then** the app warns the results will be lost and offers save, discard or
   cancel.
7. **Given** a chain with unsaved results when the app went to the background, **When** the app is
   relaunched and the chain reopened, **Then** the app offers to restore them; declining leaves its
   leaves reading "not run".

---

### Edge Cases

- A source with no stored draws: every draw collection is empty; counts are empty; count all is 0.
- A filter parameter of 0: keeping 0 yields nothing; skipping 0 yields everything.
- A filter parameter above the collection size: clamped, never an error.
- A negative or non-whole filter parameter: cannot be set.
- Sorting an empty collection or an empty count result: yields an empty result.
- Two draws on the same date: sort by date falls back to index ascending.
- A filter on a count result that was never sorted: allowed, but works on the fixed display order
  (item ascending); the person is not promised a ranking.
- Removing a block that has children: its whole subtree goes with it (confirmation is a
  presentation concern, LTA-21).
- A source's data changes (a sync) after results were computed from it: those results — shown or
  saved — read as out of date; results from other sources are unaffected.
- A chain is run against a source whose shape makes a parameter invalid (e.g. z ≥ x of that source):
  only the affected leaf fails, naming the parameter.
- A saved result whose source no longer exists: it stays viewable and reads as "source unavailable".
- Deleting a chain that has saved results: the warning names how many results will be deleted with
  it, and also says unsaved results will go when the chain has a draft; cancelling keeps all of
  them.
- The app is closed from the system (app switcher, system termination) with unsaved results: the
  platform gives no chance to ask, but the results were kept as a draft when the app went to the
  background (FR-031) and are offered back on the next open of that chain.
- A run in progress when the person leaves the chain: the run stops and produces no results; the
  chain itself is kept. Results already shown from an earlier run trigger the FR-032 warning.
- A leaf fails (e.g. over the sub-combination limit): only that leaf shows the failure.

## Requirements *(mandatory)*

### Functional Requirements

#### Data

- **FR-001**: The pipeline MUST treat every combination as a set of distinct elements whose order
  does not matter; two combinations with the same elements are equal.
- **FR-002**: A draw collection MUST hold combinations of one shape only (x elements from a pool of
  y, the same x and y for every entry), and every entry MUST keep its index and date.
- **FR-003**: Blocks MUST exchange exactly three kinds of data: a draw collection, a count result,
  and a single number.
- **FR-004**: A count result MUST be a collection of (item, count) pairs where each item appears
  once and every count is at least 1. Unsorted, it has no order of its own; after sort by count it
  is an ordered list.

#### Blocks

- **FR-005**: Filters — **drop first x**, **drop last x**, **keep first x** (prefix), **keep last x**
  (suffix) — MUST accept a draw collection or a count result and return the same kind, working on
  the input's current order.
- **FR-006**: Filter parameter x MUST be a whole number ≥ 0. A value larger than the input MUST be
  clamped: keep-first/keep-last return the whole input, drop-first/drop-last return an empty result.
- **FR-007**: **Sort by date** and **sort by index** MUST take a draw collection and return a draw
  collection; equal dates fall back to index ascending.
- **FR-008**: **Sort by count** MUST take a count result and return it ordered by count; equal counts
  fall back to item ascending (combinations and sub-combinations compared element by element in
  ascending order), whatever the direction.
- **FR-009**: Every sort MUST take a direction, ascending or descending.
- **FR-010**: Counting blocks MUST have these inputs and outputs:

  | Block | Takes | Returns |
  |---|---|---|
  | Count Unique Elements | draw collection | count result of elements (only elements that occur) |
  | Count Unique Combinations | draw collection | count result of whole combinations |
  | Count Unique Sub-combinations (z) | draw collection | count result of every z-element sub-combination of every entry |
  | Count All Elements | draw collection | single number: entries × x |

  Together with FR-005 and FR-007–FR-009 this table is the complete compatibility rule: a block may
  be attached under a parent only if the parent's output kind is one the block takes.
- **FR-011**: Count Unique Sub-combinations' z MUST be at least 2 when set, and MUST be less than x
  of the source a run uses; a z that is not fails only that leaf, naming the parameter.
- **FR-012**: A single number ends a branch: no block may be attached under Count All Elements.

#### Chains

- **FR-013**: A chain MUST be a tree whose root is its input and in which every block has exactly one
  parent. A chain is not tied to a source: each run supplies one source, whose full draw collection
  (in index ascending order — oldest first) is the root's output, and the same chain MUST be runnable
  against different sources.
- **FR-014**: A block MAY have any number of children; adding a second child creates a branch.
- **FR-015**: Attaching a block whose input kind does not match its parent's output MUST be refused
  with a reason naming the kind it needs, and MUST leave the chain unchanged.
- **FR-016**: A person MUST be able to change a block's parameters after adding it, and to remove a
  block; removing a block removes its whole subtree.
- **FR-017**: Chains MUST be saved across launches. The processing blocks page MUST list the saved
  chains by a name the person can edit, plus a way to start a new chain; from there a person can
  open a chain, run it against the chosen source, and delete it. Deleting a chain also deletes the
  results saved from it and its draft, after a warning that names how many saved results will go
  (and that unsaved results go too, when a draft exists — FR-032). Edits to a chain are kept.

#### Running

- **FR-018**: A chain MUST run only when the person asks, always against the source chosen on the
  start page; there is no separate source choice inside the chain builder. A run produces one result
  per leaf. While it
  runs, its progress MUST be visible and the app MUST stay responsive.
- **FR-019**: Within a run, each block MUST be evaluated once and its output given to all its
  children. Nothing is reused between runs.
- **FR-020**: Starting a run while one is in progress MUST stop the earlier run; only the latest
  run's results are shown.
- **FR-021**: Every result MUST record the source it was computed from and that source's data state
  (its stored draws at the time, e.g. record count and latest draw). A result MUST read as out of date,
  without anything re-running, when the chain has been edited since the run (add, remove, change a
  parameter) or when its source's data has changed since. Leaves added after the last run MUST read as
  not run.
- **FR-022**: Count Unique Sub-combinations MUST refuse to compute when the number of
  sub-combinations it would generate (entries × C(x, z)) exceeds 5,000,000, failing only that leaf
  with a message that names the limit.
- **FR-023**: A failure in one leaf MUST NOT prevent other leaves in the same run from producing
  results.

#### Results

- **FR-024**: Every block that has run — a leaf or an intermediate block — MUST offer a short
  summary of its output (e.g. "49 elements", "Total: 42,072", "7,009 unique, 3 repeat") and open a
  full result view, so a person can see any output before saving it (FR-027). A leaf's output is
  its branch's result.
- **FR-025**: A count result that has not been sorted MUST be displayed by item ascending, and the
  display MUST NOT imply a ranking.
- **FR-026**: An empty result MUST say there is nothing to show rather than appear as an error.

#### Saved results

- **FR-027**: After a run, a person MUST be able to save the output of any block in the chain — an
  intermediate block as well as a leaf.
- **FR-028**: A saved result MUST keep the output itself, the blocks and parameters that produced it
  (the path from the chain's root to that block), the source it was computed from, that source's data
  state, and when it was saved.
- **FR-029**: Saved results MUST persist across launches. Each chain MUST list the results saved from
  it, and a person MUST be able to open and delete them there.
- **FR-030**: A saved result MUST read as out of date when its source's current data state differs
  from the recorded one, and as "source unavailable" when the source no longer exists; it stays
  viewable in both cases. Editing the chain after saving does NOT make a saved result out of date: it
  shows "chain changed since" as information, and its recorded path stays the description of what
  produced it.
- **FR-031**: Results that were not saved MUST NOT survive a relaunch as results. When the app goes to
  the background while a chain has unsaved results, they MUST be kept as that chain's draft (one per
  chain, replaced by a newer one). The next time that chain is opened, the app MUST offer to restore
  the draft: restoring shows the results again, with the usual out-of-date rules (FR-021); declining
  discards it and the leaves read as not run. Saving or discarding results (FR-032) also discards the
  draft.
- **FR-032**: When the person is about to leave a chain that has unsaved results, the app MUST warn
  that those results will be lost and offer to save them, discard them, or cancel. Leaving the chain
  is the only way to reach another chain or the delete action, so this one warning covers opening
  another chain too. Deleting a chain that has a draft (FR-031) MUST say, in the FR-017 delete
  warning, that its unsaved results will be deleted as well; there is no save option from the list.

### Key Entities

- **Source**: supplies a run with the full draw collection it has stored; its data state (record
  count, latest draw) changes when it syncs.
- **Draw collection**: an ordered list of entries (index, date, combination) sharing one shape
  (x of y).
- **Combination / sub-combination**: a set of distinct elements; a sub-combination has z elements,
  2 ≤ z < x, taken from one combination.
- **Count result**: (item, count) pairs — the item is an element, a combination or a
  sub-combination; unordered until sorted by count.
- **Block**: one processing step with a kind, the data kind it takes, the data kind it returns, and
  its parameters (x for filters, direction for sorts, z for sub-combinations).
- **Chain**: a named tree of blocks rooted at an input, independent of any source and saved across
  launches; each leaf yields one result.
- **Run**: one on-demand evaluation of a chain against one source, producing a result (or a failure)
  per leaf; each result records the source and its data state.
- **Saved result**: a kept copy of one block's output from a run, with the path of blocks and
  parameters that produced it, its source, that source's data state and when it was saved; out of
  date once the source's data changes.
- **Draft**: a chain's unsaved results, kept automatically when the app goes to the background and
  offered back the next time that chain is opened; at most one per chain.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a reference data set with hand-computed answers, every block in FR-005–FR-011
  returns exactly the expected result — 100% agreement, including ties, empty inputs and clamped
  parameters.
- **SC-002**: Across every (parent kind, block) pair, the attach rule accepts exactly the pairs
  allowed by FR-010 and refuses all others — no chain that can be built fails at run time because of
  its shape.
- **SC-003**: While any run is in progress, its progress is visible and the app keeps responding —
  every tap (scrolling, opening another result, starting a new run) is acted on during the run; no
  hard time limit is set.
- **SC-004**: In a chain where one block feeds several children, that block is evaluated exactly once
  per run.
- **SC-005**: After any edit, 100% of previously shown results are marked out of date before the next
  run; none is presented as current.
- **SC-006**: A person can build and run "the ten most frequent numbers in the last 100 draws"
  (source → keep last 100 → count unique elements → sort by count descending → keep first 10) in
  under 1 minute on first use.
- **SC-007**: After a source syncs new draws, 100% of results computed from it — shown or saved,
  including after a relaunch — read as out of date, and 0% of results from other sources do.
- **SC-008**: A chain built once runs against any other source with no rebuilding: 0 blocks need to
  be re-added or re-entered.

## Assumptions

- The chosen source and its stored draws come from the existing start page and sync (specs 001,
  002); the Domain entities they are read into are delivered by LTA-6 and sub-combinations by LTA-7.
- "Count All Elements" counts element occurrences, so for a single-shape collection it equals
  entries × x; it is still computed, not assumed, so an empty collection gives 0.
- The 5,000,000 sub-combination limit (FR-022) is a starting value chosen during refinement
  (LTA-27); it is one tunable constant. No 6-of-49 history reaches it.
- Screens — the chain outline, the add-block sheet, and result views — are specified by their own
  tickets (LTA-20 to LTA-23, LTA-9, LTA-18); this spec defines only the behaviour they present.
- Leaving a chain keeps it (it is saved); a run in progress stops.
- "Processing blocks page" means the list of saved chains (FR-017); an open chain is "the chain",
  shown in its own view reached from that list.

## Out of Scope

- Sharing or exporting chains or saved results.
- Blocks beyond those listed in FR-005–FR-012.
- Combining the outputs of two branches into one block (every block has exactly one input).
- Caching results between runs or running automatically on edit.
- Visual design of the chain builder, add-block sheet and result screens (LTA-21, LTA-22, and the
  result screens of LTA-9 and LTA-18) and their implementation (LTA-23).
- Running one chain against several sources in the same run (each run uses exactly one source).
- Recomputing a saved result in place; to refresh it, the person runs the chain again and saves anew.

## Delivery Map

This spec is delivered across tickets; the order follows their dependencies.

| Ticket | Delivers |
|---|---|
| LTA-6 | Domain entities and reading a source's draws as a collection (FR-001, FR-002) |
| LTA-9 | Count Unique Elements run as a single block with its result screen (US1, FR-010 row 1, FR-024–FR-026) |
| LTA-19 | Chain model, attach rule and runner (FR-013–FR-023) |
| LTA-20 → LTA-21, LTA-22, LTA-23 | Chain builder UI (US2–US6 as the person sees them) |
| LTA-24, LTA-25, LTA-26 | Filters, sorts, count all (FR-005–FR-009, FR-010 row 4, FR-012) |
| LTA-18 | Count Unique Combinations (FR-010 row 2) |
| LTA-7, LTA-27 | Sub-combinations and their count block (FR-010 row 3, FR-011, FR-022) |
| *(no ticket yet)* | Source-independent, saved chains and saved results (FR-013, FR-017, FR-018, FR-021, FR-027–FR-032, US8) |
