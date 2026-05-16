import Foundation
import SwiftUI

struct TimeSignature: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var numerator: Int
    var denominator: Int

    var label: String {
        "\(numerator)/\(denominator)"
    }
}

@MainActor
final class MetronomeModel: ObservableObject {
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
            saveSequence()
            if currentMeasureIndex >= sequence.count {
                currentMeasureIndex = 0
                currentBeat = -1
            }
        }
    }

    @Published private(set) var tapTempoText = "TAP"
    @Published private(set) var flashBPM = false
    @Published private(set) var pendulumDirection = 0

    private let storageKey = "metro.sequence.v1"
    private let clickEngine = ClickEngine()
    private var flashTask: Task<Void, Never>?
    private var tapResetTask: Task<Void, Never>?
    private var tapTimes: [Date] = []
    private var playbackGeneration = 0

    private static let defaultSequence = [
        TimeSignature(numerator: 7, denominator: 8),
        TimeSignature(numerator: 4, denominator: 4),
        TimeSignature(numerator: 3, denominator: 4)
    ]

    init() {
        sequence = Self.loadSequence(storageKey: storageKey)
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

    func addMeasure(numerator: Int, denominator: Int) -> Bool {
        guard (1...32).contains(numerator), (1...64).contains(denominator) else {
            return false
        }

        sequence.append(TimeSignature(numerator: numerator, denominator: denominator))
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

    private func saveSequence() {
        do {
            let data = try JSONEncoder().encode(sequence)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    private static func loadSequence(storageKey: String) -> [TimeSignature] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TimeSignature].self, from: data)
        else {
            return defaultSequence
        }

        let clean = decoded.filter {
            (1...32).contains($0.numerator) && (1...64).contains($0.denominator)
        }
        return clean.isEmpty ? defaultSequence : clean
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
