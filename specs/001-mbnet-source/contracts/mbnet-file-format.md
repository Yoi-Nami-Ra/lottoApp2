# Contract: MBNet Data File Format (external input)

**Source of truth**: `http://www.mbnet.com.pl/dl.txt` (plain HTTP, `text/plain`, UTF-8, ~256 KB).
This is the external contract the `MBNetParser` consumes. Verified against a live fetch on 2026-07-29.

## Wire format

One draw per line, no header, no trailing blank line, no BOM:

```text
<index>. <DD.MM.YYYY> <n1,n2,n3,n4,n5,n6>
```

Examples (first, last observed):

```text
1. 27.01.1957 8,12,31,39,43,45
7380. 18.07.2026 5,6,12,38,41,43
```

## Field rules

| Field | Rule |
|-------|------|
| index | Positive integer, `.`-terminated, sequential from 1. Unique across the file. **De-dup key.** |
| date | `DD.MM.YYYY` (day.month.year, Polish/European order). Dates are **NOT unique** (multiple draws can share a date). |
| numbers | Exactly **6** comma-separated integers, each in **1…49** (Polish Lotto "Duży Lotek"). No spaces around commas. |
| separators | Single spaces between the three fields. |

Observed invariants (7,380 rows on 2026-07-29): 100% match `^\d+\.\s\d{2}\.\d{2}\.\d{4}\s\d+(,\d+){5}$`;
numbers min=1, max=49; 0 blank lines; full history from 1957.

## Parser contract (`MBNetParser.parse(_ text: String) -> ParseResult`)

- **Input**: the raw response body (`String`).
- **Output**: `ParseResult { draws: [DrawDTO], skipped: Int }`.
- **Behavior**:
  - Split on newlines; trim; ignore empty lines.
  - For each line, validate against the field rules. Well-formed → a `DrawDTO`. Malformed (bad index, bad
    date, ≠6 numbers, out-of-range number) → increment `skipped`, do not throw (FR-007).
  - A body that yields **zero** parseable lines from a non-empty, well-fetched response is still a *success*
    with `draws == []` (maps to the "empty history" edge case — record count 0).
  - The parser never performs I/O and never throws; transport/status failures are the caller's concern
    (`NetworkClient`/`RemoteSource.fetchData`), which throw → sync failure → alert.
- **Determinism**: pure function of its input → exhaustively unit-testable (Principle III).

## Failure taxonomy (who signals what)

| Condition | Detected by | Result |
|-----------|-------------|--------|
| Host unreachable / timeout (15s) | `NetworkClient.data` throws | `RemoteSource.fetchData` throws → `SorcesRepoImp` → `.failure(.failedToFetchData)` → alert; no write |
| Non-2xx HTTP status | `NetworkClient` live (throws on non-2xx) | same as above |
| Body not valid UTF-8 | `RemoteSource.fetchData` decode | throws → failure; no write |
| Body decodes but 0 parseable lines | `MBNetParser` | success, empty history (count 0) |
| Some lines malformed | `MBNetParser` | success; malformed skipped & counted (surfaced via `skipped`) |
