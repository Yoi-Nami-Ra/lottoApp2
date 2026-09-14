# Specification Quality Checklist: Source Selection, Bottom Action Bar & Processing Blocks Page

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-15
**Last validated**: 2026-08-16 (after the second clarification session)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

### Revision 2 — source selection added

The author's refinement (no sources → **Next** disabled; one source → chosen by default;
several sources → choose by highlight; blocks page shows a header naming the chosen source)
resolved the largest open assumption from revision 1, which had **Next** unconditional and
carrying nothing forward. The spec was restructured around it: four user stories instead of
three, 27 functional requirements instead of 13, and eight success criteria.

### Revision 3 — clarification session 2026-08-16

Five questions asked and answered; all recorded under the spec's `## Clarifications` heading.
Four of the five open assumptions listed below were confirmed by the author and promoted from
assumptions to testable requirements; a fifth question closed a gap the assumptions had missed
(the empty-state screen). Requirement count 27 → 30, success criteria 8 → 9.

Former open assumptions, now settled:

1. **With several sources, nothing is pre-chosen** — confirmed (FR-009). **Next** starts
   unavailable until the person picks.
2. **Re-tapping the chosen card keeps it chosen** — unchanged (FR-012); not raised as a
   question because the whole-card tap answer (FR-010) left it unambiguous.
3. **The choice is not persisted across app launches** — confirmed and promoted to FR-017,
   which rules out any new storage contract.
4. **Block entries stay display-only** — still an assumption, deliberately not spent a
   question: "for now let it just list" bounds it, and Out of Scope states it.
5. **The header names the source only** — confirmed and tightened into FR-022, which now
   forbids record counts, sync status, and dates in the header.

### Revision 4 — second clarification session, same day

Three further questions, all answered; requirement count 30 → 33, one new acceptance scenario
in each of User Story 1 and User Story 4. Two of the three closed contradictions that
revision 3's own answers had introduced:

- **Loading is now a distinct state** (FR-005, FR-006). Revision 3's no-sources message would
  otherwise have been shown to every user at first paint, before any result had arrived —
  the spec's own Edge Cases had papered over this rather than resolving it.
- **Returning re-loads the list** (FR-030), with the populated list held on screen throughout
  so the loading indication never replaces content the person is already reading.
- **Data readiness does not gate the choice** (FR-019). A never-synced source with no records
  is choosable and can move forward; gating it would strand a first-run person behind an
  unavailable **Next** with no way to explain it.

Newly settled in revision 3, not previously flagged:

- **Choosing happens by tapping the card body**, with the existing Refresh button carved out
  so it never moves the choice (FR-010, FR-011), and the chosen card marked by a border/tint
  **plus** a checkmark so the cue is not colour-only (FR-014).
- **The no-sources screen carries an explanatory message** rather than a blank list under a
  greyed-out button (FR-005, SC-009).

### Revision 1 history

Validation iteration 1 found one issue: SC-004 read "within a moment of the tap (no
perceptible wait)", which is not measurable. Rewritten as "fully presented within 1 second
of the tap, with no loading indicator at any point" (now SC-006).

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
