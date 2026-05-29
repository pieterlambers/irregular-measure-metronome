import Foundation

enum ForestForTheTreesSong {
    static let measure105To136ID = UUID(uuidString: "A8E40604-772B-4E31-88DF-058F3802235A")!
    static let measure446To472ID = UUID(uuidString: "6A5F5B72-5984-4A58-8A54-64E4F132BB56")!

    static var measure105To136: Song {
        Song(
            id: measure105To136ID,
            name: "The Forest for the Trees 105-136",
            bpm: 144,
            startMeasureNumber: 105,
            sequence: [
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(2, 4),
                signature(5, 8, grouping: [3, 2]),
                signature(4, 4),
                signature(5, 8, grouping: [3, 2]),
                signature(3, 4),
                signature(9, 8, grouping: [3, 3, 3]),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(3, 8),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(7, 8, grouping: [2, 2, 3]),
                signature(4, 4),
                signature(7, 8, grouping: [3, 2, 2]),
                signature(4, 4),
                signature(4, 4),
                signature(7, 8, grouping: [2, 2, 3]),
                signature(7, 8, grouping: [3, 2, 2]),
                signature(5, 8, grouping: [3, 2]),
                signature(3, 8),
                signature(5, 4),
                signature(5, 4),
                signature(4, 4),
                signature(4, 4)
            ],
            loopRange: nil,
            countInFourFourEnabled: false
        )
    }

    static var measure446To472: Song {
        Song(
            id: measure446To472ID,
            name: "The Forest for the Trees 446-472",
            bpm: 148,
            startMeasureNumber: 446,
            sequence: [
                signature(4, 4),
                signature(2, 4),
                signature(3, 4),
                signature(3, 4),
                signature(4, 4),
                signature(4, 4),
                signature(3, 4),
                signature(4, 4),
                signature(4, 4),
                signature(3, 4),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(3, 4),
                signature(3, 8),
                signature(4, 4),
                signature(7, 8, grouping: [2, 2, 3]),
                signature(4, 4),
                signature(3, 4),
                signature(3, 8),
                signature(4, 4),
                signature(7, 8, grouping: [2, 2, 3]),
                signature(3, 8),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4),
                signature(4, 4)
            ],
            loopRange: nil,
            countInFourFourEnabled: false
        )
    }

    private static func signature(
        _ numerator: Int,
        _ denominator: Int,
        grouping: [Int]? = nil
    ) -> TimeSignature {
        TimeSignature(numerator: numerator, denominator: denominator, grouping: grouping)
    }
}
