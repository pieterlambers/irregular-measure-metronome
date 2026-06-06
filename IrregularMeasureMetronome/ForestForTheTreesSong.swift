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
                signature(4, 4), // m. 105
                signature(4, 4), // m. 106
                signature(4, 4), // m. 107
                signature(4, 4), // m. 108
                signature(2, 4), // m. 109
                signature(5, 8, grouping: [3, 2]), // m. 110
                signature(4, 4), // m. 111
                signature(5, 8, grouping: [3, 2]), // m. 112
                signature(3, 4), // m. 113
                signature(9, 8, grouping: [3, 3, 3]), // m. 114
                signature(4, 4), // m. 115
                signature(4, 4), // m. 116
                signature(4, 4), // m. 117
                signature(4, 4), // m. 118
                signature(4, 4), // m. 119
                signature(3, 8), // m. 120
                signature(4, 4), // m. 121
                signature(4, 4), // m. 122
                signature(4, 4), // m. 123
                signature(7, 8, grouping: [2, 2, 3]), // m. 124
                signature(4, 4), // m. 125
                signature(7, 8, grouping: [3, 2, 2]), // m. 126
                signature(4, 4), // m. 127
                signature(4, 4), // m. 128
                signature(7, 8, grouping: [2, 2, 3]), // m. 129
                signature(7, 8, grouping: [3, 2, 2]), // m. 130
                signature(5, 8, grouping: [3, 2]), // m. 131
                signature(3, 8), // m. 132
                signature(3, 4), // m. 133
                signature(3, 4), // m. 134
                signature(4, 4), // m. 135
                signature(4, 4) // m. 136
            ],
            loopRange: nil,
            countInFourFourEnabled: false,
            isReadOnly: true
        )
    }

    static var measure446To472: Song {
        Song(
            id: measure446To472ID,
            name: "The Forest for the Trees 446-472",
            bpm: 148,
            startMeasureNumber: 446,
            sequence: [
                signature(4, 4), // m. 446
                signature(2, 4), // m. 447
                signature(3, 4), // m. 448
                signature(3, 4), // m. 449
                signature(4, 4), // m. 450
                signature(4, 4), // m. 451
                signature(3, 4), // m. 452
                signature(4, 4), // m. 453
                signature(4, 4), // m. 454
                signature(3, 4), // m. 455
                signature(4, 4), // m. 456
                signature(4, 4), // m. 457
                signature(4, 4), // m. 458
                signature(3, 4), // m. 459
                signature(3, 8), // m. 460
                signature(4, 4), // m. 461
                signature(7, 8, grouping: [2, 2, 3]), // m. 462
                signature(4, 4), // m. 463
                signature(3, 4), // m. 464
                signature(3, 8), // m. 465
                signature(4, 4), // m. 466
                signature(7, 8, grouping: [2, 2, 3]), // m. 467
                signature(3, 8), // m. 468
                signature(4, 4), // m. 469
                signature(4, 4), // m. 470
                signature(4, 4), // m. 471
                signature(4, 4) // m. 472
            ],
            loopRange: nil,
            countInFourFourEnabled: false,
            isReadOnly: true
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
