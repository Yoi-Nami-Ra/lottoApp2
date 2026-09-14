//
//  StartPage.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/07/2025.
//


import ComposableArchitecture
import Dependencies
import SwiftUI

@Reducer
struct StartPage {
    @ObservableState
    struct State: Equatable {
        var sources: IdentifiedArrayOf<SourceEntry.State> = []
        /// The chosen source — the single source of truth for the choice. A single optional makes two
        /// simultaneous selections unrepresentable rather than merely avoided.
        var selectedSourceID: SourceEntry.State.ID?
        /// `false` until the first `sourcesResponse` of this screen's life, and never reset afterwards.
        /// It is what separates "still finding out" from "there are none", and what keeps a reload after
        /// returning from swapping the populated list back to a loading indication.
        var hasLoaded: Bool = false
        @Presents var blocks: BlocksPage.State?

        var isNextEnabled: Bool { selectedSourceID != nil }

        /// Re-establishes the selection invariants after any change to `sources` or `selectedSourceID`.
        /// This is the only writer of `SourceEntry.State.isSelected`, and the only place the choice rules
        /// live, so they cannot drift apart across the call sites that trigger them.
        ///
        /// The order matters: a stale id is dropped *before* the single-source rule runs, so a list that
        /// shrinks to one source chooses the survivor instead of holding on to an id that is gone.
        mutating func applySelectionRules() {
            if let id = selectedSourceID, sources[id: id] == nil {
                selectedSourceID = nil
            }
            if sources.count == 1 {
                selectedSourceID = sources.first?.id
            }
            // `ids` already hands back a value, so the loop iterates its own copy while the body
            // writes through `sources` — no second copy is needed to keep the accesses apart.
            let chosen = selectedSourceID
            for id in sources.ids {
                sources[id: id]?.isSelected = (id == chosen)
            }
        }
    }

    enum Action {
        case task
        case sourcesResponse([Source])
        case refreshResponse(id: SourceEntry.State.ID, Result<Source, SourcesBLogic.Error>)
        case sources(IdentifiedActionOf<SourceEntry>)
        case nextButtonTapped
        case blocks(PresentationAction<BlocksPage.Action>)
    }

    private enum CancelID: nonisolated Hashable, Sendable {
        case load
        case refresh(SourceEntry.State.ID)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            @Dependency(\.blSources) var blSources
            @Dependency(\.date) var date

            switch action {
            case .task:
                return .run { send in
                    let sources = await blSources.knownSources()
                    await send(.sourcesResponse(sources))
                }
                .cancellable(id: CancelID.load, cancelInFlight: true)

            case .sourcesResponse(let sources):
                let now = date.now
                state.sources = IdentifiedArrayOf(
                    uniqueElements: sources.map { source in
                        var entry = source.sourceEntryState(now: now)
                        // Carry over transient UI state: a reload must not clear an in-flight refresh (which
                        // would drop the child's FR-020 guard and allow a second concurrent sync) or dismiss
                        // a failure alert the user hasn't seen yet.
                        if let existing = state.sources[id: entry.id] {
                            entry.isRefreshing = existing.isRefreshing
                            entry.alert = existing.alert
                        }
                        return entry
                    }
                )
                // Monotonic: the loading indication belongs to the period before the *first* result, so a
                // reload after returning from the blocks page leaves the populated list on screen.
                state.hasLoaded = true
                state.applySelectionRules()
                return .none

            case let .sources(.element(id: id, action: .delegate(.refreshRequested))):
                // FR-020: the child guards against re-entrancy; here we own the fetch and drive `isRefreshing`.
                state.sources[id: id]?.isRefreshing = true
                return .run { send in
                    await send(.refreshResponse(id: id, blSources.fetchFrom(id)))
                }
                .cancellable(id: CancelID.refresh(id), cancelInFlight: true)

            case let .refreshResponse(id: id, response):
                // The entry can be gone if the list reloaded mid-flight. Bail out rather than writing through
                // the id-subscript, which would append a ghost row and silently swallow the alert.
                guard state.sources[id: id] != nil else { return .none }
                state.sources[id: id]?.isRefreshing = false
                switch response {
                case .failure:
                    // FR-021: surface a failure alert; leave prior analytics unchanged.
                    state.sources[id: id]?.alert = .syncFailed
                case .success(let result):
                    state.sources[id: id]?.apply(result, now: date.now)
                }
                return .none

            case let .sources(.element(id: id, action: .delegate(.selectionRequested))):
                // Set the choice, then let the one ruleset settle the mirrors — so "move the highlight"
                // and "clear the previous one" cannot drift apart.
                state.selectedSourceID = id
                state.applySelectionRules()
                return .none

            case .nextButtonTapped:
                // The button is disabled without a choice; the guard is here too so the rule holds
                // however the action arrives. Assigning `blocks` is idempotent, which is what makes a
                // double tap push exactly one destination.
                guard
                    let id = state.selectedSourceID,
                    let entry = state.sources[id: id]
                else { return .none }
                state.blocks = BlocksPage.State(sourceID: entry.id, sourceName: entry.name)
                return .none

            case .sources, .blocks:
                return .none
            }
        }
        .forEach(\.sources, action: \.sources) {
            SourceEntry()
        }
        .ifLet(\.$blocks, action: \.blocks) {
            BlocksPage()
        }
    }
}

extension Int {
    var days: TimeInterval {
        TimeInterval(self) * 24.hours
    }
    var hours: TimeInterval {
        TimeInterval(self) * 60.minutes
    }
    var minutes: TimeInterval {
        TimeInterval(self) * 60.seconds
    }
    var seconds: TimeInterval { .init(self) }
}
