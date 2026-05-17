import Foundation
import SwiftUI

struct TimeSignature: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var numerator: Int
    var denominator: Int
    var grouping: [Int]?

    var label: String {
        "\(numerator)/\(denominator)"
    }

    var groupingLabel: String {
        validGrouping?.map(String.init).joined(separator: "+") ?? "None"
    }

    var validGrouping: [Int]? {
        guard let grouping,
              grouping.count > 1,
              grouping.allSatisfy({ $0 > 0 }),
              grouping.reduce(0, +) == numerator
        else { return nil }
        return grouping
    }

    func isSubaccented(beat: Int) -> Bool {
        guard beat > 0, let validGrouping else { return false }
        var groupStart = 0
        for group in validGrouping.dropLast() {
            groupStart += group
            if beat == groupStart {
                return true
            }
        }
        return false
    }
}

@MainActor
final class MetronomeModel: ObservableObject {
    @Published var startMeasureNumber: Int = 1 {
        didSet {
            let clamped = startMeasureNumber.clamped(to: 0...9999)
            if startMeasureNumber != clamped {
                startMeasureNumber = clamped
                return
            }
            saveComposition()
        }
    }

    @Published var bpm: Int = 120 {
        didSet {
            let clamped = min(300, max(20, bpm))
            if bpm != clamped {
                bpm = clamped
            }
            if isPlaying {
                restartPlaybackFromCurrentPosition()
            }
        }
    }

    @Published private(set) var isPlaying = false
    @Published private(set) var currentMeasureIndex = 0
    @Published private(set) var currentBeat = -1
    @Published private(set) var loopCount = 1
    @Published var sequence: [TimeSignature] {
        didSet {
            saveComposition()
            if currentMeasureIndex >= sequence.count {
                currentMeasureIndex = 0
                currentBeat = -1
            }
        }
    }

    @Published private(set) var tapTempoText = "TAP"
    @Published private(set) var flashBPM = false
    @Published private(set) var pendulumDirection = 0

    private let compositionStorageKey = "metro.composition.v2"
    private let legacySequenceStorageKey = "metro.sequence.v1"
    private let clickEngine = ClickEngine()
    private var flashTask: Task<Void, Never>?
    private var tapResetTask: Task<Void, Never>?
    private var tapTimes: [Date] = []
    private var playbackGeneration = 0

    private static let defaultSequence = [
        TimeSignature(numerator: 7, denominator: 8, grouping: [2, 2, 3]),
        TimeSignature(numerator: 4, denominator: 4),
        TimeSignature(numerator: 3, denominator: 4)
    ]

    init() {
        let composition = Self.loadComposition(
            compositionStorageKey: compositionStorageKey,
            legacySequenceStorageKey: legacySequenceStorageKey
        )
        startMeasureNumber = composition.startMeasureNumber
        sequence = composition.sequence
    }

    var tempoName: String {
        let map: [(Int, String)] = [
            (20, "Larghissimo"),
            (40, "Largo"),
            (60, "Larghetto"),
            (66, "Adagio"),
            (76, "Andante"),
            (108, "Moderato"),
            (120, "Allegretto"),
            (156, "Allegro"),
            (176, "Vivace"),
            (200, "Presto"),
            (240, "Prestissimo")
        ]

        return map.reduce("Larghissimo") { name, item in
            bpm >= item.0 ? item.1 : name
        }
    }

    var currentMeasure: TimeSignature {
        guard sequence.indices.contains(currentMeasureIndex) else {
            return TimeSignature(numerator: 4, denominator: 4)
        }
        return sequence[currentMeasureIndex]
    }

    func measureNumber(forIndex index: Int) -> Int {
        startMeasureNumber + index
    }

    func togglePlayback() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !sequence.isEmpty else { return }
        isPlaying = true
        currentBeat = -1
        currentMeasureIndex = 0
        loopCount = 1
        pendulumDirection = 0
        startPlayback(measureIndex: 0, beat: 0, loopCount: 1)
    }

    func stop() {
        isPlaying = false
        playbackGeneration += 1
        clickEngine.stop()
        flashTask?.cancel()
        flashBPM = false
        currentBeat = -1
        pendulumDirection = 0
    }

    func tapTempo() {
        let now = Date()
        tapTimes.append(now)
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }

        tapResetTask?.cancel()
        tapResetTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.tapTimes.removeAll()
                self?.tapTempoText = "TAP"
            }
        }

        guard tapTimes.count >= 2 else { return }

        let diffs = zip(tapTimes.dropFirst(), tapTimes).map { newer, older in
            newer.timeIntervalSince(older)
        }
        let average = diffs.reduce(0, +) / Double(diffs.count)
        bpm = Int((60 / average).rounded()).clamped(to: 20...300)
        tapTempoText = "\(bpm)"
    }

    func insertMeasure(after measure: TimeSignature, numerator: Int, denominator: Int) -> Bool {
        guard let index = sequence.firstIndex(where: { $0.id == measure.id }) else {
            return false
        }
        return insertMeasure(at: index + 1, numerator: numerator, denominator: denominator)
    }

    func insertMeasure(at index: Int, numerator: Int, denominator: Int) -> Bool {
        guard (1...24).contains(numerator), (1...64).contains(denominator) else {
            return false
        }

        let insertionIndex = index.clamped(to: 0...sequence.count)
        sequence.insert(TimeSignature(numerator: numerator, denominator: denominator), at: insertionIndex)
        if isPlaying {
            stop()
        }
        return true
    }

    func duplicateMeasure(at index: Int) -> Bool {
        guard !sequence.isEmpty else { return false }
        let templateIndex = index == 0 ? 0 : (index - 1).clamped(to: 0...(sequence.count - 1))
        let template = sequence[templateIndex]
        let copy = TimeSignature(
            numerator: template.numerator,
            denominator: template.denominator,
            grouping: template.validGrouping
        )
        sequence.insert(copy, at: index.clamped(to: 0...sequence.count))
        if isPlaying {
            stop()
        }
        return true
    }

    func deleteMeasure(_ measure: TimeSignature) {
        guard sequence.count > 1 else { return }
        sequence.removeAll { $0.id == measure.id }
        if isPlaying {
            stop()
        }
    }

    func updateMeasure(_ measure: TimeSignature, numerator: Int, denominator: Int) -> Bool {
        guard (1...24).contains(numerator), (1...64).contains(denominator),
              let index = sequence.firstIndex(where: { $0.id == measure.id })
        else {
            return false
        }

        sequence[index].numerator = numerator
        sequence[index].denominator = denominator
        sequence[index].grouping = Self.cleanGrouping(sequence[index].grouping, numerator: numerator)
        if isPlaying {
            stop()
        }
        return true
    }

    func updateGrouping(for measure: TimeSignature, grouping: [Int]?) {
        guard let index = sequence.firstIndex(where: { $0.id == measure.id }) else { return }
        let cleaned = Self.cleanGrouping(grouping, numerator: sequence[index].numerator)
        guard sequence[index].grouping != cleaned else { return }
        sequence[index].grouping = cleaned
        if isPlaying {
            stop()
        }
    }

    private func startPlayback(measureIndex: Int, beat: Int, loopCount: Int) {
        playbackGeneration += 1
        let generation = playbackGeneration
        clickEngine.start(
            bpm: bpm,
            sequence: sequence,
            startMeasureIndex: measureIndex,
            startBeat: beat,
            loopCount: loopCount
        ) { [weak self] measureIndex, beat, loopCount in
            Task { @MainActor [weak self] in
                self?.showScheduledBeat(
                    measureIndex: measureIndex,
                    beat: beat,
                    loopCount: loopCount,
                    generation: generation
                )
            }
        }
    }

    private func restartPlaybackFromCurrentPosition() {
        let beat = max(0, currentBeat)
        startPlayback(measureIndex: currentMeasureIndex, beat: beat, loopCount: loopCount)
    }

    private func showScheduledBeat(measureIndex: Int, beat: Int, loopCount: Int, generation: Int) {
        guard isPlaying,
              generation == playbackGeneration,
              sequence.indices.contains(measureIndex)
        else { return }
        currentMeasureIndex = measureIndex
        currentBeat = beat
        self.loopCount = loopCount
        flash()
        pendulumDirection = pendulumDirection == 0 ? 1 : -pendulumDirection
    }

    private func flash() {
        flashTask?.cancel()
        flashBPM = true
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.flashBPM = false
            }
        }
    }

    private func saveComposition() {
        do {
            let composition = PersistedComposition(
                startMeasureNumber: startMeasureNumber,
                sequence: sequence
            )
            let data = try JSONEncoder().encode(composition)
            UserDefaults.standard.set(data, forKey: compositionStorageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: compositionStorageKey)
        }
    }

    private static func loadComposition(
        compositionStorageKey: String,
        legacySequenceStorageKey: String
    ) -> PersistedComposition {
        if let data = UserDefaults.standard.data(forKey: compositionStorageKey),
           let decoded = try? JSONDecoder().decode(PersistedComposition.self, from: data) {
            return PersistedComposition(
                startMeasureNumber: decoded.startMeasureNumber.clamped(to: 0...9999),
                sequence: cleanSequence(decoded.sequence)
            )
        }

        if let data = UserDefaults.standard.data(forKey: legacySequenceStorageKey),
           let decoded = try? JSONDecoder().decode([TimeSignature].self, from: data) {
            return PersistedComposition(
                startMeasureNumber: 1,
                sequence: cleanSequence(decoded)
            )
        }

        return PersistedComposition(startMeasureNumber: 1, sequence: defaultSequence)
    }

    private static func cleanSequence(_ sequence: [TimeSignature]) -> [TimeSignature] {
        let clean = sequence.filter {
            (1...24).contains($0.numerator) && (1...64).contains($0.denominator)
        }
        .map {
            TimeSignature(
                id: $0.id,
                numerator: $0.numerator,
                denominator: $0.denominator,
                grouping: cleanGrouping($0.grouping, numerator: $0.numerator)
            )
        }
        return clean.isEmpty ? defaultSequence : clean
    }

    private static func cleanGrouping(_ grouping: [Int]?, numerator: Int) -> [Int]? {
        guard let grouping,
              grouping.count > 1,
              grouping.allSatisfy({ (1...4).contains($0) }),
              grouping.reduce(0, +) == numerator
        else { return nil }
        return grouping
    }
}

private struct PersistedComposition: Codable {
    var startMeasureNumber: Int
    var sequence: [TimeSignature]
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
