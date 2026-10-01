# ``lottoApp2``

Syncs lottery draw history from its sources and runs chains of processing blocks over it.

## Overview

An app to do some operations on random games data

## Scenarios

### S01 Refreshing sources
**the app is launched**
- the app lists all the known sources with data:
    - name of source
    - last refresh with severity highlight
        (o1) - basic — shipped before spec 001 (the initial start page)
            - blue - never — shown with a "Fetch" button since spec 008
            - green - low - less than 2 days
            - yellow - medium - 2 days but less than 4
            - red - high - 4 or more days
        (o2) - update 01 — shipped in spec 009 (missing records estimate)
            | taking two last full weeks, can estimate how many records are missing
    - first record date
    - last record date
    - count of all records
- each source entry has a \\refresh\\ button
**the user clicks/taps refresh button on a given source**
- the refresh button changes its form to signal processing

## TODO
-- open feature work is tracked in the `.tickets/` backlog (LTA-N), including linting and view snapshot tests
++ general
    ++ UI automation tests — an XCUITest happy path in `lottoApp2UITests` (LTA-23)
++ shipped specs
    ++ 001 - real MBNet server source
    ++ 002 - source selection, bottom action bar and processing blocks page
    ++ 003 - processing block pipeline
    ++ 004 - specific sync errors
    ++ 005 - skipped rows note
    ++ 006 - chain-builder design gaps
    ++ 007 - compact and wide source cards
    ++ 008 - Fetch button on never-synced sources
    ++ 009 - missing records estimate
