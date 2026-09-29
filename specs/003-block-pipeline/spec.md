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
- Q: What shape can a chain have? → A: A tree: the source is the root, each block has exactly one
  input, and one block's output can feed several blocks.
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
- Q: Are chains saved? → A: No — they last for the session, like the chosen source.
- Q: How are results presented? → A: Each leaf shows a short summary and opens its own result screen.

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
4. **Given** z = 1 or z = x, **When** the person sets it, **Then** the value is refused (z must be at
   least 2 and less than x).
5. **Given** a z whose work exceeds the limit in FR-022, **When** the chain runs, **Then** that leaf
   reports it was too large to compute and names the limit; other leaves still produce results.

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
- The source's data changes (a sync) while a chain exists: existing results are marked out of date.
- A run in progress when the person leaves the page: the run stops; nothing is kept (session only,
  the chain itself stays for the session).
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
- **FR-011**: Count Unique Sub-combinations' z MUST satisfy 2 ≤ z < x of the collection's shape.
- **FR-012**: A single number ends a branch: no block may be attached under Count All Elements.

#### Chains

- **FR-013**: A chain MUST be a tree whose root is the chosen source (output: its full draw
  collection) and in which every block has exactly one parent.
- **FR-014**: A block MAY have any number of children; adding a second child creates a branch.
- **FR-015**: Attaching a block whose input kind does not match its parent's output MUST be refused
  with a reason naming the kind it needs, and MUST leave the chain unchanged.
- **FR-016**: A person MUST be able to change a block's parameters after adding it, and to remove a
  block; removing a block removes its whole subtree.
- **FR-017**: Chains MUST last for the session only and are not saved across launches.

#### Running

- **FR-018**: A chain MUST run only when the person asks; a run produces one result per leaf.
- **FR-019**: Within a run, each block MUST be evaluated once and its output given to all its
  children. Nothing is reused between runs.
- **FR-020**: Starting a run while one is in progress MUST stop the earlier run; only the latest
  run's results are shown.
- **FR-021**: After a run, any edit to the chain (add, remove, change a parameter) or a change in the
  source's stored data MUST mark existing results out of date without re-running. Leaves added after
  the last run MUST read as not run.
- **FR-022**: Count Unique Sub-combinations MUST refuse to compute when the number of
  sub-combinations it would generate (entries × C(x, z)) exceeds 5,000,000, failing only that leaf
  with a message that names the limit.
- **FR-023**: A failure in one leaf MUST NOT prevent other leaves in the same run from producing
  results.

#### Results

- **FR-024**: Each leaf MUST offer a short summary of its result (e.g. "49 elements", "Total:
  42,072", "7,009 unique, 3 repeat") and open a full result view.
- **FR-025**: A count result that has not been sorted MUST be displayed by item ascending, and the
  display MUST NOT imply a ranking.
- **FR-026**: An empty result MUST say there is nothing to show rather than appear as an error.

### Key Entities

- **Source**: the root of a chain; provides the full draw collection it has stored.
- **Draw collection**: an ordered list of entries (index, date, combination) sharing one shape
  (x of y).
- **Combination / sub-combination**: a set of distinct elements; a sub-combination has z elements,
  2 ≤ z < x, taken from one combination.
- **Count result**: (item, count) pairs — the item is an element, a combination or a
  sub-combination; unordered until sorted by count.
- **Block**: one processing step with a kind, the data kind it takes, the data kind it returns, and
  its parameters (x for filters, direction for sorts, z for sub-combinations).
- **Chain**: a tree of blocks rooted at a source; each leaf yields one result.
- **Run**: one on-demand evaluation of a chain, producing a result (or a failure) per leaf; results
  become out of date after an edit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a reference data set with hand-computed answers, every block in FR-005–FR-011
  returns exactly the expected result — 100% agreement, including ties, empty inputs and clamped
  parameters.
- **SC-002**: Across every (parent kind, block) pair, the attach rule accepts exactly the pairs
  allowed by FR-010 and refuses all others — no chain that can be built fails at run time because of
  its shape.
- **SC-003**: Running Count Unique Elements on the full MBNet history (about 7,000 draws) shows its
  result within 1 second of the person asking.
- **SC-004**: A chain with at least 5 leaves over the full MBNet history runs in under 3 seconds, and
  a shared block with several children is evaluated once per run.
- **SC-005**: After any edit, 100% of previously shown results are marked out of date before the next
  run; none is presented as current.
- **SC-006**: A person can build and run "the ten most frequent numbers in the last 100 draws"
  (source → keep last 100 → count unique elements → sort by count descending → keep first 10) in
  under 1 minute on first use.

## Assumptions

- The chosen source and its stored draws come from the existing start page and sync (specs 001,
  002); the Domain entities they are read into are delivered by LTA-6 and sub-combinations by LTA-7.
- The entries' "current order" before any sort is the stored order (by index ascending).
- "Count All Elements" counts element occurrences, so for a single-shape collection it equals
  entries × x; it is still computed, not assumed, so an empty collection gives 0.
- The 5,000,000 sub-combination limit (FR-022) is a starting value chosen during refinement
  (LTA-27); it is one tunable constant. No 6-of-49 history reaches it.
- Performance targets (SC-003, SC-004) assume a current iPhone and the full MBNet history.
- Screens — the chain outline, the add-block sheet, and result views — are specified by their own
  tickets (LTA-20 to LTA-23, LTA-9, LTA-18); this spec defines only the behaviour they present.
- Leaving the processing blocks page keeps the chain for the session; a run in progress stops.

## Out of Scope

- Saving chains across launches, sharing or exporting them.
- Blocks beyond those listed in FR-005–FR-012.
- Combining the outputs of two branches into one block (every block has exactly one input).
- Caching results between runs or running automatically on edit.
- Visual design of the chain builder, add-block sheet and result screens (LTA-21, LTA-22, and the
  result screens of LTA-9 and LTA-18) and their implementation (LTA-23).
- Multi-source chains (a chain has exactly one source).

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
