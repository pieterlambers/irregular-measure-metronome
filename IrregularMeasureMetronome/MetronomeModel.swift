import Foundation
import SwiftUI

struct TimeSignature: Identifiable, Codable, Equatable {
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
                rescheduleUpcomingTick()
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
    private var nextTickTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var tapResetTask: Task<Void, Never>?
    private var tapTimes: [Date] = []
    private var pendingMeasureIndex = 0
    private var pendingBeat = 0

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
        clickEngine.prepare()
        isPlaying = true
        currentBeat = 0
        currentMeasureIndex = 0
        pendingBeat = 0
        pendingMeasureIndex = 0
        loopCount = 1
        pendulumDirection = 1
        tick()
    }

    func stop() {
        isPlaying = false
        nextTickTask?.cancel()
        nextTickTask = nil
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

    private func tick() {
        guard isPlaying, !sequence.isEmpty else { return }
        let measure = currentMeasure
        let beatForClick = currentBeat
        let delay = intervalMilliseconds(for: measure)

        clickEngine.playClick(accented: beatForClick == 0)
        flash()
        pendulumDirection *= -1

        pendingBeat = currentBeat + 1
        pendingMeasureIndex = currentMeasureIndex
        if pendingBeat >= measure.numerator {
            pendingBeat = 0
            pendingMeasureIndex += 1
            if pendingMeasureIndex >= sequence.count {
                pendingMeasureIndex = 0
                loopCount += 1
            }
        }

        rescheduleUpcomingTick(after: delay)
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

    private func scheduleNextTick(
        after milliseconds: Double,
        action: (() -> Void)? = nil
    ) {
        nextTickTask?.cancel()
        guard isPlaying else { return }

        nextTickTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(milliseconds.rounded())))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if let action {
                    action()
                } else {
                    self?.tick()
                }
            }
        }
    }

    private func rescheduleUpcomingTick(after milliseconds: Double? = nil) {
        scheduleNextTick(after: milliseconds ?? intervalMilliseconds()) { [weak self] in
            guard let self else { return }
            self.currentBeat = self.pendingBeat
            self.currentMeasureIndex = self.pendingMeasureIndex
            self.tick()
        }
    }

    private func intervalMilliseconds(for measure: TimeSignature? = nil) -> Double {
        let measure = measure ?? currentMeasure
        return (60000 / Double(bpm)) * (4 / Double(measure.denominator))
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
