//
//  BlockTokens.swift
//  lottoApp2
//
//  Copy and imagery for blocks, shared by the chain outline, the add-block sheet and the parameter step,
//  so a block reads the same everywhere. Exhaustive `switch`es: a new block fails to compile until it has
//  its copy, instead of rendering blank.
//

import SwiftUI

/// The add-block sheet's sections, in their fixed order (LTA-22).
enum CatalogueSection: CaseIterable {
    case filter
    case sort
    case count

    var kinds: [ProcessingBlockKind] {
        ProcessingBlockKind.allCases.filter { $0.catalogueSection == self }
    }
}

extension ProcessingBlockKind {
    var catalogueSection: CatalogueSection {
        switch self {
        case .dropFirst, .dropLast, .prefix, .suffix: .filter
        case .sortByDate, .sortByIndex, .sortByCount: .sort
        case .countUniqueElements, .countUniqueCombinations, .countUniqueSubCombinations, .countAllElements: .count
        }
    }
}

// MARK: - Resources
extension LocalizedStringKey {
    static func blockTitle(_ kind: ProcessingBlockKind) -> Self {
        switch kind {
        case .dropFirst: "Drop First"
        case .dropLast: "Drop Last"
        case .prefix: "Prefix"
        case .suffix: "Suffix"
        case .sortByDate: "Sort by Date"
        case .sortByIndex: "Sort by Index"
        case .sortByCount: "Sort by Count"
        case .countUniqueElements: "Count Unique Elements"
        case .countUniqueCombinations: "Count Unique Combinations"
        case .countUniqueSubCombinations: "Count Unique Sub-combinations"
        case .countAllElements: "Count All Elements"
        }
    }

    /// The parameter step's title when it edits an existing block (LTA-22).
    static func blockEditTitle(_ kind: ProcessingBlockKind) -> Self {
        switch kind {
        case .dropFirst: "Edit Drop First"
        case .dropLast: "Edit Drop Last"
        case .prefix: "Edit Prefix"
        case .suffix: "Edit Suffix"
        case .sortByDate: "Edit Sort by Date"
        case .sortByIndex: "Edit Sort by Index"
        case .sortByCount: "Edit Sort by Count"
        case .countUniqueElements: "Edit Count Unique Elements"
        case .countUniqueCombinations: "Edit Count Unique Combinations"
        case .countUniqueSubCombinations: "Edit Count Unique Sub-combinations"
        case .countAllElements: "Edit Count All Elements"
        }
    }

    /// The one-liner under a block in the catalogue; `nil` when the title says it all.
    static func blockTagline(_ kind: ProcessingBlockKind) -> Self? {
        switch kind {
        case .dropFirst: "Skip the first x"
        case .dropLast: "Skip the last x"
        case .prefix: "Keep the first x"
        case .suffix: "Keep the last x"
        case .countUniqueSubCombinations: "Pairs, triples… of size z"
        case .sortByDate, .sortByIndex, .sortByCount, .countUniqueElements, .countUniqueCombinations, .countAllElements: nil
        }
    }

    /// What the block does, on its parameter step.
    static func blockExplanation(_ kind: ProcessingBlockKind) -> Self {
        switch kind {
        case .dropFirst: "Skips the first x items in their current order."
        case .dropLast: "Skips the last x items in their current order."
        case .prefix: "Keeps the first x items in their current order."
        case .suffix: "Keeps the last x items in their current order."
        case .sortByDate: "Orders draws by date; draws on the same date by index, ascending."
        case .sortByIndex: "Orders draws by their index."
        case .sortByCount: "Orders counts; equal counts by item, ascending."
        case .countUniqueElements: "Each element drawn, with how many times it occurs."
        case .countUniqueCombinations: "Each whole draw, with how many times it was drawn."
        case .countUniqueSubCombinations: "Every z-element part of every draw, with how many times it occurs. z must be at least 2 and below the draw size."
        case .countAllElements: "Every drawn element, counted. Its total ends the branch."
        }
    }

    /// A configured block's parameters as its outline row shows them; `nil` without parameters.
    static func blockParameters(_ block: Block) -> Self? {
        switch block {
        case .dropFirst(let x): "skip first \(x.formatted())"
        case .dropLast(let x): "skip last \(x.formatted())"
        case .prefix(let x): "first \(x.formatted())"
        case .suffix(let x): "last \(x.formatted())"
        case .sortByDate(let direction), .sortByIndex(let direction), .sortByCount(let direction): .direction(direction)
        case .countUniqueSubCombinations(let z): "size \(z.formatted())"
        case .countUniqueElements, .countUniqueCombinations, .countAllElements: nil
        }
    }

    static func direction(_ direction: SortDirection) -> Self {
        switch direction {
        case .ascending: "ascending"
        case .descending: "descending"
        }
    }

    static func catalogueSection(_ section: CatalogueSection) -> Self {
        switch section {
        case .filter: "Filter"
        case .sort: "Sort"
        case .count: "Count"
        }
    }

    /// Why a kind is unavailable under a parent (LTA-22).
    static func needs(_ kinds: Set<ValueKind>) -> Self {
        kinds.contains(.counts) && !kinds.contains(.draws)
            ? "Needs counts — add a count block first"
            : "Needs draws — add it under the source or a filter"
    }

    /// Why a node that ran produced no value (FR-011, FR-022, FR-023).
    static func failure(_ failure: BlockFailure) -> Self {
        switch failure {
        case .overBudget(let limit): "Too large — over \(limit.formatted()) sub-combinations"
        case .invalidParameter("z"): "z must be below this source's draw size"
        case .invalidParameter: "A parameter doesn't fit this source"
        case .upstreamFailed: "Not run — an earlier block failed"
        case .cancelled: "Stopped"
        }
    }

    static func valueKind(_ kind: ValueKind) -> Self {
        switch kind {
        case .draws: "Draws"
        case .counts: "Counts"
        case .number: "Number"
        }
    }

    static func summary(_ summary: ValueSummary) -> Self {
        switch summary {
        case .draws(let count): "\(count.formatted()) draws"
        case .elements(let count): "\(count.formatted()) elements"
        case let .combinations(unique, repeating): "\(unique.formatted()) unique, \(repeating.formatted()) repeat"
        case let .subCombinations(unique, _): "\(unique.formatted()) unique"
        case .number(let total): "Total: \(total.formatted())"
        case .empty(.draws): "No draws"
        case .empty(.counts): "Nothing to count"
        case .empty(.number): "Nothing"
        }
    }
}

extension LocalizedStringKey {
    // MARK: Parameter step hints (spec 006, design/final/add-block-sheet.html)

    /// How big the parent was in its last run, under x (FR-001).
    static func parentSizeHint(_ size: BlockParameters.ParentSize) -> Self {
        switch (size.unit, size.count) {
        case (.draws, 1): "Of 1 draw. A larger x keeps them all."
        case (.draws, let count): "Of \(count.formatted()) draws. A larger x keeps them all."
        case (.items, 1): "Of 1 item. A larger x keeps them all."
        case (.items, let count): "Of \(count.formatted()) items. A larger x keeps them all."
        }
    }

    /// The value an edit started from, and what saving does (FR-003); `nil` for a block without parameters.
    static func wasHint(_ block: Block) -> Self? {
        switch block {
        case .dropFirst(let x), .dropLast(let x), .prefix(let x), .suffix(let x):
            "Was \(x.formatted()). Saving marks this block's results out of date."
        case .countUniqueSubCombinations(let z):
            "Was \(z.formatted()). Saving marks this block's results out of date."
        case .sortByDate(.ascending), .sortByIndex(.ascending), .sortByCount(.ascending):
            "Was Ascending. Saving marks this block's results out of date."
        case .sortByDate(.descending), .sortByIndex(.descending), .sortByCount(.descending):
            "Was Descending. Saving marks this block's results out of date."
        case .countUniqueElements, .countUniqueCombinations, .countAllElements: nil
        }
    }

    /// What the chosen direction means (FR-004).
    static func directionPreview(_ preview: BlockParameters.DirectionPreview) -> Self {
        switch preview {
        case .mostFrequent: "Most frequent first."
        case .leastFrequent: "Least frequent first."
        case .oldest: "Oldest first."
        case .newest: "Newest first."
        case .lowestIndex: "Lowest index first."
        case .highestIndex: "Highest index first."
        }
    }

    /// Why the typed number is refused (FR-005–FR-008, LTA-22).
    static func invalidReason(_ reason: BlockParameters.InvalidReason) -> Self {
        switch reason {
        case .atLeast(let minimum): "Enter a whole number, \(minimum.formatted()) or more."
        case let .range(minimum, maximum): "Enter a whole number from \(minimum.formatted()) to \(maximum.formatted())."
        case .drawsTooSmall: "This source's draws are too small for sub-combinations."
        }
    }

    // MARK: Accessibility readings (spec 006 FR-010, FR-013, FR-014)

    /// A disabled catalogue row: "<block>, unavailable, <reason>".
    static func unavailableReading(_ kind: ProcessingBlockKind, needs kinds: Set<ValueKind>) -> Self {
        "\(Text(.blockTitle(kind))), unavailable, \(Text(.needs(kinds)))"
    }

    static func addBlockUnder(_ kind: ProcessingBlockKind) -> Self { "Add block under \(Text(.blockTitle(kind)))" }
    static func addBlockUnder(sourceName: String) -> Self { "Add block under \(sourceName)" }

    static func levelReading(_ depth: Int) -> Self { "level \(depth.formatted())" }

    static func sourceRowReading(name: String, count: Int?) -> Self {
        switch count {
        case .none: "\(name), source"
        case .some(1): "\(name), source, 1 draw"
        case .some(let count): "\(name), source, \(count.formatted()) draws"
        }
    }

    static let runningReading: Self = "Running"
    static let savedReading: Self = "Saved"
    /// Joins the parts of one spoken row.
    static let readingSeparator: Self = ", "
}

extension Text {
    /// One accessibility reading from its parts, in order, separated as a list.
    static func reading(_ parts: [Text]) -> Text {
        guard let first = parts.first else { return Text(verbatim: "") }
        return parts.dropFirst().reduce(first) { $0 + Text(.readingSeparator) + $1 }
    }
}

extension LocalizedStringResource {
    /// A block's title as plain text, for places that join several of them (a saved result's path).
    static func blockName(_ kind: ProcessingBlockKind) -> Self {
        switch kind {
        case .dropFirst: "Drop First"
        case .dropLast: "Drop Last"
        case .prefix: "Prefix"
        case .suffix: "Suffix"
        case .sortByDate: "Sort by Date"
        case .sortByIndex: "Sort by Index"
        case .sortByCount: "Sort by Count"
        case .countUniqueElements: "Count Unique Elements"
        case .countUniqueCombinations: "Count Unique Combinations"
        case .countUniqueSubCombinations: "Count Unique Sub-combinations"
        case .countAllElements: "Count All Elements"
        }
    }
}

extension ImageType {
    static let block: Self = .system("function")
    static let chainInput: Self = .system("list.bullet.rectangle")
}
