# ``lottoApp2``

<!--@START_MENU_TOKEN@-->Summary<!--@END_MENU_TOKEN@-->

## Overview

An app to do some operations on random games data

## Scenarios

### S01 Refreshing sources
**the app is alunched**
- the app lists all the known sources with data:
    - name of source
    - last refresh with severity highlite
        (o1) - basic
            - blue - never
            - green - low - les than 2 days
            - yellow - medium - 2 days but less than 4
            - red - high - 4 or more days
        (o2) - update 01
            | taking two last full weeks, can estimate how many records are missing
    - first record date
    - last record date
    - count of all records
- each source entry has a \\refresh\\ button
**the user clicks/taps refresh button on a given source**
- the refresh button changes it's form to signal processing

## TODO
-- general
    -- do we want a way to test views with screenshots?
    -- do we want ui auto tests?
    -- linting
-- startPage
    -- list known sources
        ++ View + moc Reducer
            ++ startPage
            ++ sourceEntry
        ++ StartPage Reducer + moc BLogic
            ++ tests
        ++ SourceEntry Reducer +
            ++ tests
        ++ BLogic + moc repository
            ++ tests
        -+ Repository Impl + mock Data
            -- tests
        -- Data
            -- tests
-- source entry
-- 001 - source selection as a part of the start page
    -- 002 - Design
        -- (mobile) source name and severity indicator with ability to refresh
        -- (desktop) full card
-- 003 - hardcoded sources with basic data, this should be represented in visual layer as well by signaling that given source is not available to compute but can be fetched
    -- "Fetch" button when source never fetched before
