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

struct Song: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var bpm: Int
    var startMeasureNumber: Int
    var sequence: [TimeSignature]
    var loopRange: PersistedLoopRange?
    var countInFourFourEnabled: Bool?
    var updatedAt: Date = Date()
}

@MainActor
final class MetronomeModel: ObservableObject {
    @Published private(set) var songs: [Song] = []
    @Published private(set) var currentSongID = UUID()
    @Published var currentSongName = "" {
        didSet {
            let limitedName = String(currentSongName.prefix(60))
            if currentSongName != limitedName {
                currentSongName = limitedName
                return
            }
            saveCurrentSong()
        }
    }

    @Published var startMeasureNumber: Int = 1 {
        didSet {
            let clamped = startMeasureNumber.clamped(to: 0...9999)
            if startMeasureNumber != clamped {
                startMeasureNumber = clamped
                return
            }
            saveCurrentSong()
        }
    }

    @Published var bpm: Int = 120 {
        didSet {
            let clamped = min(300, max(20, bpm))
            if bpm != clamped {
                bpm = clamped
                return
            }
            if isPlaying {
                restartPlaybackFromCurrentPosition()
            }
            saveCurrentSong()
        }
    }

    @Published private(set) var isPlaying = false
    @Published private(set) var currentMeasureIndex = 0
    @Published private(set) var currentBeat = -1
    @Published private(set) var loopCount = 1
    @Published private(set) var isCountingIn = false
    @Published var isCountInFourFourEnabled = false {
        didSet {
            guard oldValue != isCountInFourFourEnabled else { return }
            saveCurrentSong()
            restartPlaybackAtLoopStartIfNeeded()
        }
    }
    @Published var isLoopRangeEnabled = false {
        didSet {
            guard oldValue != isLoopRangeEnabled else { return }
            saveCurrentSong()
            restartPlaybackAtLoopStartIfNeeded()
        }
    }
    @Published private(set) var loopStartIndex = 0
    @Published private(set) var loopEndIndex = 0
    @Published var sequence: [TimeSignature] = [] {
        didSet {
            let hadFullDisabledLoopRange = !isLoopRangeEnabled
                && loopStartIndex == 0
                && loopEndIndex >= max(0, oldValue.count - 1)
            normalizeLoopRange()
            if hadFullDisabledLoopRange {
                loopStartIndex = 0
                loopEndIndex = max(0, sequence.count - 1)
            }
            if currentMeasureIndex >= sequence.count {
                currentMeasureIndex = 0
                currentBeat = -1
            }
            saveCurrentSong()
        }
    }

    @Published private(set) var tapTempoText = "TAP"
    @Published private(set) var flashBPM = false
    @Published private(set) var pendulumDirection = 0

    private let compositionStorageKey = "metro.composition.v2"
    private let legacySequenceStorageKey = "metro.sequence.v1"
    private let songLibraryStorageKey = "metro.songLibrary.v1"
    private let clickEngine: ClickEngineProtocol
    private let userDefaults: UserDefaults
    private let now: () -> Date
    private let tapResetDelay: Duration
    private var flashTask: Task<Void, Never>?
    private var tapResetTask: Task<Void, Never>?
    private var tapTimes: [Date] = []
    private var playbackGeneration = 0
    private var isApplyingSong = false

    private static let defaultSequence = [
        TimeSignature(numerator: 7, denominator: 8, grouping: [2, 2, 3]),
        TimeSignature(numerator: 4, denominator: 4),
        TimeSignature(numerator: 3, denominator: 4)
    ]
    private static let builtInSongs = [
        ForestForTheTreesSong.measure105To136,
        ForestForTheTreesSong.measure446To472
    ]

    init(
        clickEngine: ClickEngineProtocol = ClickEngine(),
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        tapResetDelay: Duration = .milliseconds(2500)
    ) {
        self.clickEngine = clickEngine
        self.userDefaults = userDefaults
        self.now = now
        self.tapResetDelay = tapResetDelay
        let library = Self.loadSongLibrary(
            userDefaults: userDefaults,
            songLibraryStorageKey: songLibraryStorageKey,
            compositionStorageKey: compositionStorageKey,
            legacySequenceStorageKey: legacySequenceStorageKey
        )
        songs = library.songs
        let currentSong = library.songs.first { $0.id == library.currentSongID } ?? library.songs[0]
        applySong(currentSong, savePreviousSong: false)
        normalizeLoopRange()
        saveSongLibrary()
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
        if isCountingIn {
            return TimeSignature(numerator: 4, denominator: 4)
        }
        guard sequence.indices.contains(currentMeasureIndex) else {
            return TimeSignature(numerator: 4, denominator: 4)
        }
        return sequence[currentMeasureIndex]
    }

    var currentSong: Song {
        songs.first { $0.id == currentSongID } ?? Self.defaultSong()
    }

    var canResetCurrentSongToBuiltIn: Bool {
        Self.builtInSongs.contains { $0.id == currentSongID }
    }

    func selectSong(_ song: Song) {
        guard song.id != currentSongID else { return }
        guard let storedSong = songs.first(where: { $0.id == song.id }) else { return }
        applySong(storedSong, savePreviousSong: true)
        saveSongLibrary()
    }

    func createSong() {
        saveCurrentSong()
        stop()

        let song = Self.defaultSong(named: nextUntitledSongName())
        songs.append(song)
        applySong(song, savePreviousSong: false)
        saveSongLibrary()
    }

    func duplicateCurrentSong() {
        saveCurrentSong()
        stop()

        var song = currentSong
        song.id = UUID()
        song.name = nextCopyName(for: song.name)
        song.updatedAt = Date()
        song.sequence = song.sequence.map {
            TimeSignature(
                numerator: $0.numerator,
                denominator: $0.denominator,
                grouping: $0.validGrouping
            )
        }
        songs.append(song)
        applySong(song, savePreviousSong: false)
        saveSongLibrary()
    }

    func resetCurrentSongToBuiltIn() {
        guard var builtInSong = Self.builtInSongs.first(where: { $0.id == currentSongID }) else { return }
        builtInSong.updatedAt = Date()
        if let index = songs.firstIndex(where: { $0.id == builtInSong.id }) {
            songs[index] = builtInSong
        } else {
            songs.append(builtInSong)
        }
        applySong(builtInSong, savePreviousSong: false)
        saveSongLibrary()
    }

    func deleteCurrentSong() {
        guard songs.count > 1 else { return }
        let deletedID = currentSongID
        let nextSong = songs.first { $0.id != deletedID } ?? Self.defaultSong()
        stop()
        songs.removeAll { $0.id == deletedID }
        applySong(nextSong, savePreviousSong: false)
        saveSongLibrary()
    }

    func measureNumber(forIndex index: Int) -> Int {
        startMeasureNumber + index
    }

    var lastMeasureNumber: Int {
        startMeasureNumber + max(0, sequence.count - 1)
    }

    var loopStartMeasureNumber: Int {
        measureNumber(forIndex: loopStartIndex)
    }

    var loopEndMeasureNumber: Int {
        measureNumber(forIndex: loopEndIndex)
    }

    func updateLoopStartMeasureNumber(_ measureNumber: Int) {
        guard !sequence.isEmpty else { return }
        let index = index(forMeasureNumber: measureNumber)
            .clamped(to: 0...loopEndIndex)
        guard loopStartIndex != index else { return }
        loopStartIndex = index
        saveCurrentSong()
        restartPlaybackAtLoopStartIfNeeded()
    }

    func updateLoopEndMeasureNumber(_ measureNumber: Int) {
        guard !sequence.isEmpty else { return }
        let index = index(forMeasureNumber: measureNumber)
            .clamped(to: loopStartIndex...(sequence.count - 1))
        guard loopEndIndex != index else { return }
        loopEndIndex = index
        saveCurrentSong()
        restartPlaybackAtLoopStartIfNeeded()
    }

    func isMeasureInActiveLoop(index: Int) -> Bool {
        isLoopRangeEnabled && (loopStartIndex...loopEndIndex).contains(index)
    }

    func togglePlayback() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !sequence.isEmpty else { return }
        isPlaying = true
        currentBeat = -1
        currentMeasureIndex = activeLoopStartIndex
        loopCount = 1
        isCountingIn = false
        pendulumDirection = 0
        startPlayback(
            measureIndex: activeLoopStartIndex,
            beat: 0,
            loopCount: 1,
            includeCountIn: isCountInFourFourEnabled
        )
    }

    func stop() {
        isPlaying = false
        playbackGeneration += 1
        clickEngine.stop()
        flashTask?.cancel()
        flashBPM = false
        currentBeat = -1
        isCountingIn = false
        pendulumDirection = 0
    }

    func tapTempo() {
        let tapTime = now()
        tapTimes.append(tapTime)
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }

        tapResetTask?.cancel()
        let tapResetDelay = tapResetDelay
        tapResetTask = Task { [weak self] in
            try? await Task.sleep(for: tapResetDelay)
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

    private func startPlayback(
        measureIndex: Int,
        beat: Int,
        loopCount: Int,
        includeCountIn: Bool = false
    ) {
        playbackGeneration += 1
        let generation = playbackGeneration
        clickEngine.start(
            bpm: bpm,
            sequence: sequence,
            startMeasureIndex: measureIndex,
            startBeat: beat,
            loopStartIndex: activeLoopStartIndex,
            loopEndIndex: activeLoopEndIndex,
            loopCount: loopCount,
            countInBeats: includeCountIn ? 4 : 0
        ) { [weak self] measureIndex, beat, loopCount, isCountIn in
            Task { @MainActor [weak self] in
                self?.showScheduledBeat(
                    measureIndex: measureIndex,
                    beat: beat,
                    loopCount: loopCount,
                    isCountIn: isCountIn,
                    generation: generation
                )
            }
        }
    }

    private func restartPlaybackFromCurrentPosition() {
        if isCountingIn {
            currentBeat = -1
            currentMeasureIndex = activeLoopStartIndex
            loopCount = 1
            isCountingIn = false
            startPlayback(
                measureIndex: activeLoopStartIndex,
                beat: 0,
                loopCount: 1,
                includeCountIn: isCountInFourFourEnabled
            )
            return
        }

        let beat = max(0, currentBeat)
        let measureIndex = currentMeasureIndex.clamped(to: activeLoopStartIndex...activeLoopEndIndex)
        isCountingIn = false
        startPlayback(measureIndex: measureIndex, beat: beat, loopCount: loopCount)
    }

    private var activeLoopStartIndex: Int {
        guard isLoopRangeEnabled else { return 0 }
        return loopStartIndex
    }

    private var activeLoopEndIndex: Int {
        guard isLoopRangeEnabled else { return max(0, sequence.count - 1) }
        return loopEndIndex
    }

    private func restartPlaybackAtLoopStartIfNeeded() {
        guard isPlaying else { return }
        currentBeat = -1
        currentMeasureIndex = activeLoopStartIndex
        loopCount = 1
        isCountingIn = false
        pendulumDirection = 0
        startPlayback(
            measureIndex: activeLoopStartIndex,
            beat: 0,
            loopCount: 1,
            includeCountIn: isCountInFourFourEnabled
        )
    }

    private func index(forMeasureNumber measureNumber: Int) -> Int {
        measureNumber - startMeasureNumber
    }

    private func normalizeLoopRange() {
        guard !sequence.isEmpty else {
            loopStartIndex = 0
            loopEndIndex = 0
            return
        }

        let lastIndex = sequence.count - 1
        loopStartIndex = loopStartIndex.clamped(to: 0...lastIndex)
        loopEndIndex = loopEndIndex.clamped(to: 0...lastIndex)
        if loopStartIndex > loopEndIndex {
            loopStartIndex = loopEndIndex
        }
    }

    private func showScheduledBeat(
        measureIndex: Int,
        beat: Int,
        loopCount: Int,
        isCountIn: Bool,
        generation: Int
    ) {
        guard isPlaying,
              generation == playbackGeneration,
              sequence.indices.contains(measureIndex)
        else { return }
        currentMeasureIndex = measureIndex
        currentBeat = beat
        self.loopCount = loopCount
        isCountingIn = isCountIn
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

    private func saveCurrentSong() {
        guard !isApplyingSong else { return }
        let cleanSequence = Self.cleanSequence(sequence)
        let song = Song(
            id: currentSongID,
            name: Self.cleanSongName(currentSongName),
            bpm: bpm.clamped(to: 20...300),
            startMeasureNumber: startMeasureNumber.clamped(to: 0...9999),
            sequence: cleanSequence,
            loopRange: PersistedLoopRange(
                isEnabled: isLoopRangeEnabled,
                startIndex: loopStartIndex.clamped(to: 0...max(0, cleanSequence.count - 1)),
                endIndex: loopEndIndex.clamped(to: 0...max(0, cleanSequence.count - 1))
            ),
            countInFourFourEnabled: isCountInFourFourEnabled,
            updatedAt: Date()
        )

        if let index = songs.firstIndex(where: { $0.id == currentSongID }) {
            songs[index] = song
        } else {
            songs.append(song)
        }
        saveSongLibrary()
    }

    private func saveSongLibrary() {
        do {
            let library = PersistedSongLibrary(currentSongID: currentSongID, songs: songs)
            let data = try JSONEncoder().encode(library)
            userDefaults.set(data, forKey: songLibraryStorageKey)
        } catch {
            userDefaults.removeObject(forKey: songLibraryStorageKey)
        }
    }

    private func applySong(_ song: Song, savePreviousSong: Bool) {
        if savePreviousSong {
            saveCurrentSong()
        }
        stop()

        isApplyingSong = true
        currentSongID = song.id
        currentSongName = Self.cleanSongName(song.name)
        bpm = song.bpm.clamped(to: 20...300)
        startMeasureNumber = song.startMeasureNumber.clamped(to: 0...9999)
        sequence = Self.cleanSequence(song.sequence)
        isCountInFourFourEnabled = song.countInFourFourEnabled ?? false
        isLoopRangeEnabled = song.loopRange?.isEnabled ?? false
        loopStartIndex = song.loopRange?.startIndex ?? 0
        loopEndIndex = song.loopRange?.endIndex ?? max(0, sequence.count - 1)
        normalizeLoopRange()
        currentMeasureIndex = 0
        currentBeat = -1
        loopCount = 1
        isCountingIn = false
        pendulumDirection = 0
        isApplyingSong = false
    }

    private static func loadSongLibrary(
        userDefaults: UserDefaults,
        songLibraryStorageKey: String,
        compositionStorageKey: String,
        legacySequenceStorageKey: String
    ) -> PersistedSongLibrary {
        if let data = userDefaults.data(forKey: songLibraryStorageKey),
           let decoded = try? JSONDecoder().decode(PersistedSongLibrary.self, from: data) {
            let songs = cleanSongs(decoded.songs)
            let currentSongID = songs.contains { $0.id == decoded.currentSongID }
                ? decoded.currentSongID
                : songs[0].id
            return PersistedSongLibrary(currentSongID: currentSongID, songs: songs)
        }

        if let data = userDefaults.data(forKey: compositionStorageKey),
           let decoded = try? JSONDecoder().decode(PersistedComposition.self, from: data) {
            let song = Song(
                name: "Song 1",
                bpm: 120,
                startMeasureNumber: decoded.startMeasureNumber.clamped(to: 0...9999),
                sequence: cleanSequence(decoded.sequence),
                loopRange: decoded.loopRange,
                countInFourFourEnabled: false
            )
            return PersistedSongLibrary(currentSongID: song.id, songs: cleanSongs([song]))
        }

        if let data = userDefaults.data(forKey: legacySequenceStorageKey),
           let decoded = try? JSONDecoder().decode([TimeSignature].self, from: data) {
            let song = Song(
                name: "Song 1",
                bpm: 120,
                startMeasureNumber: 1,
                sequence: cleanSequence(decoded),
                loopRange: nil,
                countInFourFourEnabled: false
            )
            return PersistedSongLibrary(currentSongID: song.id, songs: cleanSongs([song]))
        }

        let song = defaultSong(named: "Song 1")
        return PersistedSongLibrary(currentSongID: song.id, songs: cleanSongs([song]))
    }

    private static func cleanSongs(_ songs: [Song]) -> [Song] {
        let cleanSongs = songs.enumerated().compactMap { index, song -> Song? in
            let hasValidSignature = song.sequence.contains {
                (1...24).contains($0.numerator) && (1...64).contains($0.denominator)
            }
            guard hasValidSignature else { return nil }
            let sequence = cleanSequence(song.sequence)
            return Song(
                id: song.id,
                name: cleanSongName(song.name, fallback: "Song \(index + 1)"),
                bpm: song.bpm.clamped(to: 20...300),
                startMeasureNumber: song.startMeasureNumber.clamped(to: 0...9999),
                sequence: sequence,
                loopRange: song.loopRange,
                countInFourFourEnabled: song.countInFourFourEnabled ?? false,
                updatedAt: song.updatedAt
            )
        }

        let storedSongs = cleanSongs.isEmpty ? [defaultSong(named: "Song 1")] : cleanSongs
        return storedSongs + builtInSongs.filter { builtInSong in
            !storedSongs.contains { $0.id == builtInSong.id }
        }
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

    private static func cleanSongName(_ name: String, fallback: String = "Untitled Song") -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallback
        }
        return String(trimmed.prefix(60))
    }

    private static func defaultSong(named name: String = "Song 1") -> Song {
        Song(
            name: name,
            bpm: 120,
            startMeasureNumber: 1,
            sequence: defaultSequence,
            loopRange: nil,
            countInFourFourEnabled: false
        )
    }

    private func nextUntitledSongName() -> String {
        let existingNames = Set(songs.map(\.name))
        for number in 1...999 {
            let name = "Song \(number)"
            if !existingNames.contains(name) {
                return name
            }
        }
        return "Song \(songs.count + 1)"
    }

    private func nextCopyName(for name: String) -> String {
        let base = "\(Self.cleanSongName(name)) Copy"
        let existingNames = Set(songs.map(\.name))
        if !existingNames.contains(base) {
            return base
        }
        for number in 2...999 {
            let candidate = "\(base) \(number)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }
        return "\(base) \(songs.count + 1)"
    }
}

struct PersistedComposition: Codable {
    var startMeasureNumber: Int
    var sequence: [TimeSignature]
    var loopRange: PersistedLoopRange?
}

struct PersistedSongLibrary: Codable {
    var currentSongID: UUID
    var songs: [Song]
}

struct PersistedLoopRange: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var startIndex: Int
    var endIndex: Int
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
