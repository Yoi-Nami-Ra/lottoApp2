# Quickstart: validating LTA-17

Run these from the repository root.

## 1. Baseline test count (before the rename)

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests -skipMacroValidation 2>&1 | grep -E "Test run with|tests? in"
```

Record the number of tests that ran. If the simulators are wedged, use the `My Mac` destination for both
runs, so the two counts are comparable.

## 2. No misspelled name left (SC-001)

```bash
git grep -n "Sorces" -- ':!specs/' ':!.tickets/17.yaml'
```

Expected: no output.

## 3. Renames are renames (SC-005)

```bash
git log --follow --oneline -- lottoApp2/Data/Repos/SourcesRepoImpl.swift | tail -3
```

Expected: commits from before the rename are listed (for example spec 001's work). Run the same check for
`lottoApp2Tests/SourcesRepoImplTests.swift`.

## 4. Build and tests green, count unchanged (SC-002)

Re-run step 1. Expected: the build succeeds, 0 tests fail, and the count equals the baseline.

## 5. DocC page (SC-003, SC-004)

```bash
xcrun docc convert lottoApp2/Documentation.docc --output-path "$TMPDIR/lta17.doccarchive" 2>&1 | grep -i warning
```

```bash
grep -c "START_MENU_TOKEN" lottoApp2/Documentation.docc/Documentation.md
```

Expected: no warnings from the convert, and a count of `0`. Then read the TODO list and check two things:
every `++` line names a spec or ticket, and no open line duplicates a `.tickets/` title (see research R4).
