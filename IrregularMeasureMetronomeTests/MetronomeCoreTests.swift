import XCTest
@testable import IrregularMeasureMetronome

final class TimeSignatureTests: XCTestCase {
    func testLabelAndGroupingLabel() {
        let signature = TimeSignature(numerator: 7, denominator: 8, grouping: [2, 2, 3])

        XCTAssertEqual(signature.label, "7/8")
        XCTAssertEqual(signature.groupingLabel, "2+2+3")
    }

    func testValidGroupingRequiresMultiplePositiveGroupsThatSumToNumerator() {
        XCTAssertEqual(TimeSignature(numerator: 7, denominator: 8, grouping: [2, 2, 3]).validGrouping, [2, 2, 3])
        XCTAssertNil(TimeSignature(numerator: 7, denominator: 8, grouping: nil).validGrouping)
        XCTAssertNil(TimeSignature(numerator: 7, denominator: 8, grouping: [7]).validGrouping)
        XCTAssertNil(TimeSignature(numerator: 7, denominator: 8, grouping: [2, 0, 5]).validGrouping)
        XCTAssertNil(TimeSignature(numerator: 7, denominator: 8, grouping: [2, -1, 6]).validGrouping)
        XCTAssertNil(TimeSignature(numerator: 7, denominator: 8, grouping: [5, 2]).validGrouping)
        XCTAssertNil(TimeSignature(numerator: 7, denominator: 8, grouping: [3, 3]).validGrouping)
    }

    func testGroupingPresetsDoNotIncludeSingleGroupEquivalentsOfNone() {
        XCTAssertEqual(TimeSignature.groupingPresets(for: 2), [])
        XCTAssertEqual(TimeSignature.groupingPresets(for: 3), [])
        XCTAssertEqual(TimeSignature.groupingPresets(for: 4), [[2, 2]])
    }

    func testGroupingPresetsOnlyIncludeValidMeaningfulGroupings() {
        for numerator in 1...24 {
            for grouping in TimeSignature.groupingPresets(for: numerator) {
                XCTAssertEqual(TimeSignature.cleanGrouping(grouping, numerator: numerator), grouping)
            }
        }
    }

    func testGroupingPresetsKeepUsefulGeneratedAndCuratedOptions() {
        XCTAssertEqual(TimeSignature.groupingPresets(for: 6), [[3, 3], [2, 2, 2]])
        XCTAssertEqual(TimeSignature.groupingPresets(for: 8), [[3, 3, 2], [3, 2, 3], [2, 3, 3]])
        XCTAssertEqual(TimeSignature.groupingPresets(for: 12), [[3, 3, 3, 3], [2, 2, 2, 2, 2, 2], [4, 4, 4]])
    }

    func testSubaccentedBeatsAreInternalGroupStartsOnly() {
        let signature = TimeSignature(numerator: 7, denominator: 8, grouping: [2, 2, 3])

        XCTAssertFalse(signature.isSubaccented(beat: 0))
        XCTAssertFalse(signature.isSubaccented(beat: 1))
        XCTAssertTrue(signature.isSubaccented(beat: 2))
        XCTAssertFalse(signature.isSubaccented(beat: 3))
        XCTAssertTrue(signature.isSubaccented(beat: 4))
        XCTAssertFalse(signature.isSubaccented(beat: 6))
        XCTAssertFalse(signature.isSubaccented(beat: 7))
    }
}

final class PlaybackCursorTests: XCTestCase {
    private let sequence = [
        TimeSignature(numerator: 3, denominator: 4),
        TimeSignature(numerator: 5, denominator: 8),
        TimeSignature(numerator: 4, denominator: 4)
    ]

    func testAllowsStartMeasureBeforeLoopRange() {
        let cursor = PlaybackCursor(
            bpm: 120,
            sequence: sequence,
            startMeasureIndex: 0,
            startBeat: 0,
            loopStartIndex: 1,
            loopEndIndex: 2,
            loopCount: 1,
            countInBeats: 0
        )

        XCTAssertEqual(cursor.measureIndex, 0)
        XCTAssertEqual(cursor.loopStartIndex, 1)
        XCTAssertEqual(cursor.loopEndIndex, 2)
    }

    func testPreLoopStartWrapsToLoopStartAfterLoopEnd() {
        var cursor = PlaybackCursor(
            bpm: 120,
            sequence: sequence,
            startMeasureIndex: 0,
            startBeat: 2,
            loopStartIndex: 1,
            loopEndIndex: 2,
            loopCount: 1,
            countInBeats: 0
        )

        cursor.advancePastCurrentBeat()
        XCTAssertEqual(cursor.measureIndex, 1)
        XCTAssertEqual(cursor.beat, 0)

        cursor.measureIndex = 2
        cursor.beat = 3
        cursor.advancePastCurrentBeat()

        XCTAssertEqual(cursor.measureIndex, 1)
        XCTAssertEqual(cursor.beat, 0)
        XCTAssertEqual(cursor.loopCount, 2)
    }

    func testNormalizesOversizedStartBeatToZero() {
        let cursor = PlaybackCursor(
            bpm: 120,
            sequence: sequence,
            startMeasureIndex: 1,
            startBeat: 99,
            loopStartIndex: 0,
            loopEndIndex: 2,
            loopCount: 1,
            countInBeats: 0
        )

        XCTAssertEqual(cursor.beat, 0)
    }

    func testAdvancesWithinAndAcrossMeasures() {
        var cursor = PlaybackCursor(
            bpm: 120,
            sequence: sequence,
            startMeasureIndex: 0,
            startBeat: 1,
            loopStartIndex: 0,
            loopEndIndex: 2,
            loopCount: 1,
            countInBeats: 0
        )

        cursor.advancePastCurrentBeat()
        XCTAssertEqual(cursor.measureIndex, 0)
        XCTAssertEqual(cursor.beat, 2)

        cursor.advancePastCurrentBeat()
        XCTAssertEqual(cursor.measureIndex, 1)
        XCTAssertEqual(cursor.beat, 0)
    }

    func testWrapsAtLoopEndAndIncrementsLoopCount() {
        var cursor = PlaybackCursor(
            bpm: 120,
            sequence: sequence,
            startMeasureIndex: 2,
            startBeat: 3,
            loopStartIndex: 1,
            loopEndIndex: 2,
            loopCount: 4,
            countInBeats: 0
        )

        cursor.advancePastCurrentBeat()

        XCTAssertEqual(cursor.measureIndex, 1)
        XCTAssertEqual(cursor.beat, 0)
        XCTAssertEqual(cursor.loopCount, 5)
    }

    func testCountInAdvancesBeforeSequence() {
        var cursor = PlaybackCursor(
            bpm: 120,
            sequence: sequence,
            startMeasureIndex: 1,
            startBeat: 0,
            loopStartIndex: 0,
            loopEndIndex: 2,
            loopCount: -3,
            countInBeats: -1
        )

        XCTAssertEqual(cursor.loopCount, 1)
        XCTAssertEqual(cursor.countInBeatsRemaining, 0)

        cursor = PlaybackCursor(
            bpm: 120,
            sequence: sequence,
            startMeasureIndex: 1,
            startBeat: 0,
            loopStartIndex: 0,
            loopEndIndex: 2,
            loopCount: 1,
            countInBeats: 2
        )

        XCTAssertTrue(cursor.isCountingIn)
        XCTAssertEqual(cursor.countInBeat, 0)

        cursor.advancePastCurrentBeat()
        XCTAssertEqual(cursor.countInBeatsRemaining, 1)
        XCTAssertEqual(cursor.countInBeat, 1)
        XCTAssertEqual(cursor.measureIndex, 1)

        cursor.advancePastCurrentBeat()
        XCTAssertFalse(cursor.isCountingIn)
        XCTAssertEqual(cursor.countInBeat, 0)
        XCTAssertEqual(cursor.measureIndex, 1)
    }
}

@MainActor
final class MetronomeModelSequenceTests: XCTestCase {
    func testInsertMeasureAcceptsValidInputsAndClampsIndex() {
        let harness = ModelHarness()
        let model = harness.model
        let originalCount = model.sequence.count

        XCTAssertTrue(model.insertMeasure(at: -10, numerator: 5, denominator: 8))
        XCTAssertEqual(model.sequence[0].label, "5/8")

        XCTAssertTrue(model.insertMeasure(at: 999, numerator: 6, denominator: 4))
        XCTAssertEqual(model.sequence.count, originalCount + 2)
        XCTAssertEqual(model.sequence.last?.label, "6/4")
    }

    func testInsertMeasureRejectsInvalidInputs() {
        let harness = ModelHarness()
        let model = harness.model
        let originalSequence = model.sequence

        XCTAssertFalse(model.insertMeasure(at: 0, numerator: 0, denominator: 4))
        XCTAssertFalse(model.insertMeasure(at: 0, numerator: 25, denominator: 4))
        XCTAssertFalse(model.insertMeasure(at: 0, numerator: 4, denominator: 0))
        XCTAssertFalse(model.insertMeasure(at: 0, numerator: 4, denominator: 65))
        XCTAssertEqual(model.sequence, originalSequence)
    }

    func testDuplicateMeasureUsesPreviousTemplateAndCleansGrouping() {
        let harness = ModelHarness()
        let model = harness.model
        let first = model.sequence[0]
        model.updateGrouping(for: first, grouping: [2, 2, 3])

        XCTAssertTrue(model.duplicateMeasure(at: 1))

        XCTAssertEqual(model.sequence[1].numerator, 7)
        XCTAssertEqual(model.sequence[1].denominator, 8)
        XCTAssertEqual(model.sequence[1].grouping, [2, 2, 3])
        XCTAssertNotEqual(model.sequence[1].id, model.sequence[0].id)
    }

    func testDeleteMeasureDoesNotDeleteFinalMeasure() {
        let harness = ModelHarness()
        let model = harness.model

        while model.sequence.count > 1 {
            model.deleteMeasure(model.sequence[0])
        }

        let finalMeasure = model.sequence[0]
        model.deleteMeasure(finalMeasure)

        XCTAssertEqual(model.sequence, [finalMeasure])
    }

    func testUpdateMeasureClearsInvalidGrouping() {
        let harness = ModelHarness()
        let model = harness.model
        let measure = model.sequence[0]
        model.updateGrouping(for: measure, grouping: [2, 2, 3])

        XCTAssertTrue(model.updateMeasure(model.sequence[0], numerator: 4, denominator: 4))

        XCTAssertEqual(model.sequence[0].label, "4/4")
        XCTAssertNil(model.sequence[0].grouping)
    }

    func testSequenceMutationStopsPlayback() {
        let harness = ModelHarness()
        let model = harness.model
        let initialStopCount = harness.clickEngine.stopCount

        model.start()
        XCTAssertTrue(model.isPlaying)

        XCTAssertTrue(model.insertMeasure(at: 0, numerator: 5, denominator: 4))

        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(harness.clickEngine.stopCount, initialStopCount + 1)
    }
}

@MainActor
final class MetronomeModelLoopRangeTests: XCTestCase {
    func testMeasureNumbersDeriveFromStartMeasureNumber() {
        let harness = ModelHarness()
        let model = harness.model
        model.startMeasureNumber = 446

        XCTAssertEqual(model.measureNumber(forIndex: 0), 446)
        XCTAssertEqual(model.measureNumber(forIndex: 2), 448)
        XCTAssertEqual(model.lastMeasureNumber, 448)
    }

    func testLoopBoundarySettersMapDisplayNumbersToIndicesAndClamp() {
        let harness = ModelHarness()
        let model = harness.model
        model.startMeasureNumber = 10

        model.updateLoopStartMeasureNumber(12)
        XCTAssertEqual(model.loopStartIndex, 2)
        XCTAssertEqual(model.loopStartMeasureNumber, 12)

        model.updateLoopEndMeasureNumber(11)
        XCTAssertEqual(model.loopEndIndex, 2)

        model.updateLoopStartMeasureNumber(-100)
        XCTAssertEqual(model.loopStartIndex, 0)

        model.updateLoopEndMeasureNumber(100)
        XCTAssertEqual(model.loopEndIndex, model.sequence.count - 1)
    }

    func testDisabledLoopRangeStartsWholeSequence() {
        let harness = ModelHarness()
        let model = harness.model
        model.updateLoopStartMeasureNumber(model.startMeasureNumber + 1)
        model.updateLoopEndMeasureNumber(model.startMeasureNumber + 1)
        model.isLoopRangeEnabled = false

        model.start()

        XCTAssertEqual(harness.clickEngine.starts.last?.loopStartIndex, 0)
        XCTAssertEqual(harness.clickEngine.starts.last?.loopEndIndex, model.sequence.count - 1)
    }

    func testEnabledLoopRangeStartsActiveRange() {
        let harness = ModelHarness()
        let model = harness.model
        model.updateLoopStartMeasureNumber(model.startMeasureNumber + 1)
        model.updateLoopEndMeasureNumber(model.startMeasureNumber + 2)
        model.isLoopRangeEnabled = true

        model.start()

        XCTAssertEqual(harness.clickEngine.starts.last?.loopStartIndex, 1)
        XCTAssertEqual(harness.clickEngine.starts.last?.loopEndIndex, 2)
        XCTAssertTrue(model.isMeasureInActiveLoop(index: 1))
        XCTAssertFalse(model.isMeasureInActiveLoop(index: 0))
    }

    func testSequenceShrinkNormalizesLoopRangeAndCurrentMeasure() async {
        let harness = ModelHarness()
        let model = harness.model
        model.updateLoopStartMeasureNumber(model.startMeasureNumber + 1)
        model.updateLoopEndMeasureNumber(model.startMeasureNumber + 2)
        model.isLoopRangeEnabled = true
        model.start()
        harness.clickEngine.starts.last?.onBeat(2, 0, 1, false)
        await Task.yield()

        model.sequence = [model.sequence[0]]

        XCTAssertEqual(model.loopStartIndex, 0)
        XCTAssertEqual(model.loopEndIndex, 0)
        XCTAssertEqual(model.currentMeasureIndex, 0)
        XCTAssertEqual(model.currentBeat, -1)
    }
}

@MainActor
final class MetronomeModelPlaybackTests: XCTestCase {
    func testStartSetsStateAndCallsClickEngine() {
        let harness = ModelHarness()
        let model = harness.model
        model.bpm = 148
        model.isCountInFourFourEnabled = true

        model.start()

        XCTAssertTrue(model.isPlaying)
        XCTAssertEqual(model.currentBeat, -1)
        XCTAssertEqual(model.currentMeasureIndex, 0)
        XCTAssertEqual(model.loopCount, 1)

        let start = harness.clickEngine.starts.last
        XCTAssertEqual(start?.bpm, 148)
        XCTAssertEqual(start?.startMeasureIndex, 0)
        XCTAssertEqual(start?.startBeat, 0)
        XCTAssertEqual(start?.loopStartIndex, 0)
        XCTAssertEqual(start?.loopEndIndex, model.sequence.count - 1)
        XCTAssertEqual(start?.loopCount, 1)
        XCTAssertEqual(start?.countInBeats, 4)
    }

    func testStopResetsTransientStateAndStopsClickEngine() async {
        let harness = ModelHarness()
        let model = harness.model
        let initialStopCount = harness.clickEngine.stopCount
        model.start()
        harness.clickEngine.starts.last?.onBeat(0, 0, 2, false)
        await Task.yield()

        model.stop()

        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.currentBeat, -1)
        XCTAssertFalse(model.isCountingIn)
        XCTAssertFalse(model.flashBPM)
        XCTAssertEqual(harness.clickEngine.stopCount, initialStopCount + 1)
    }

    func testBPMChangeWhilePlayingRestartsFromCurrentPosition() async {
        let harness = ModelHarness()
        let model = harness.model
        model.start()
        harness.clickEngine.starts.last?.onBeat(1, 2, 3, false)
        await Task.yield()

        model.bpm = 160

        let restart = harness.clickEngine.starts.last
        XCTAssertEqual(harness.clickEngine.starts.count, 2)
        XCTAssertEqual(restart?.bpm, 160)
        XCTAssertEqual(restart?.startMeasureIndex, 1)
        XCTAssertEqual(restart?.startBeat, 2)
        XCTAssertEqual(restart?.loopCount, 3)
        XCTAssertEqual(restart?.countInBeats, 0)
    }

    func testBeatCallbacksUpdateVisiblePlaybackState() async {
        let harness = ModelHarness()
        let model = harness.model
        model.start()

        harness.clickEngine.starts.last?.onBeat(1, 3, 2, true)
        await Task.yield()

        XCTAssertEqual(model.currentMeasureIndex, 1)
        XCTAssertEqual(model.currentBeat, 3)
        XCTAssertEqual(model.loopCount, 2)
        XCTAssertTrue(model.isCountingIn)
        XCTAssertTrue(model.flashBPM)

        harness.clickEngine.starts.last?.onBeat(1, 4, 2, false)
        await Task.yield()
        XCTAssertEqual(model.currentBeat, 4)
        XCTAssertFalse(model.isCountingIn)
    }

    func testPlayedMeasurePredicateOnlyHighlightsAudibleSequenceMeasure() async {
        let harness = ModelHarness()
        let model = harness.model
        model.start()

        XCTAssertFalse(model.isPlayedMeasure(index: 0))

        harness.clickEngine.starts.last?.onBeat(1, 3, 2, true)
        await Task.yield()

        XCTAssertFalse(model.isPlayedMeasure(index: 1))

        harness.clickEngine.starts.last?.onBeat(1, 4, 2, false)
        await Task.yield()

        XCTAssertTrue(model.isPlayedMeasure(index: 1))
        XCTAssertFalse(model.isPlayedMeasure(index: 0))

        model.stop()

        XCTAssertFalse(model.isPlayedMeasure(index: 1))
    }

    func testStaleCallbacksAreIgnored() async {
        let harness = ModelHarness()
        let model = harness.model

        model.start()
        let staleCallback = harness.clickEngine.starts.last?.onBeat
        model.stop()
        model.start()

        staleCallback?(2, 2, 9, false)
        await Task.yield()

        XCTAssertEqual(model.currentMeasureIndex, 0)
        XCTAssertEqual(model.currentBeat, -1)
        XCTAssertEqual(model.loopCount, 1)
    }

    func testTapMeasureStartsPlaybackAtTappedMeasureWithoutLoopRange() {
        let harness = ModelHarness()
        let model = harness.model

        model.start(atMeasureIndex: 2)

        let start = harness.clickEngine.starts.last
        XCTAssertTrue(model.isPlaying)
        XCTAssertEqual(model.currentMeasureIndex, 2)
        XCTAssertEqual(model.currentBeat, -1)
        XCTAssertEqual(start?.startMeasureIndex, 2)
        XCTAssertEqual(start?.loopStartIndex, 0)
        XCTAssertEqual(start?.loopEndIndex, model.sequence.count - 1)
    }

    func testTapMeasureInsideLoopRangeStartsThereAndKeepsLoopRange() {
        let harness = ModelHarness()
        let model = harness.model
        model.updateLoopStartMeasureNumber(model.startMeasureNumber + 1)
        model.updateLoopEndMeasureNumber(model.startMeasureNumber + 2)
        model.isLoopRangeEnabled = true

        model.start(atMeasureIndex: 2)

        let start = harness.clickEngine.starts.last
        XCTAssertTrue(model.isLoopRangeEnabled)
        XCTAssertEqual(model.currentMeasureIndex, 2)
        XCTAssertEqual(start?.startMeasureIndex, 2)
        XCTAssertEqual(start?.loopStartIndex, 1)
        XCTAssertEqual(start?.loopEndIndex, 2)
    }

    func testTapMeasureBeforeLoopRangeStartsBeforeRangeThenLoopsRange() {
        let harness = ModelHarness()
        let model = harness.model
        model.updateLoopStartMeasureNumber(model.startMeasureNumber + 1)
        model.updateLoopEndMeasureNumber(model.startMeasureNumber + 2)
        model.isLoopRangeEnabled = true

        model.start(atMeasureIndex: 0)

        let start = harness.clickEngine.starts.last
        XCTAssertTrue(model.isLoopRangeEnabled)
        XCTAssertEqual(model.currentMeasureIndex, 0)
        XCTAssertEqual(start?.startMeasureIndex, 0)
        XCTAssertEqual(start?.loopStartIndex, 1)
        XCTAssertEqual(start?.loopEndIndex, 2)
    }

    func testTapMeasureAfterLoopRangeDisablesLoopRangeAndStartsThere() {
        let harness = ModelHarness()
        let model = harness.model
        model.updateLoopEndMeasureNumber(model.startMeasureNumber + 1)
        model.isLoopRangeEnabled = true

        model.start(atMeasureIndex: 2)

        let start = harness.clickEngine.starts.last
        XCTAssertFalse(model.isLoopRangeEnabled)
        XCTAssertEqual(model.currentMeasureIndex, 2)
        XCTAssertEqual(start?.startMeasureIndex, 2)
        XCTAssertEqual(start?.loopStartIndex, 0)
        XCTAssertEqual(start?.loopEndIndex, model.sequence.count - 1)
    }

    func testTapMeasureCountInLeadsIntoTappedMeasure() {
        let harness = ModelHarness()
        let model = harness.model
        model.isCountInFourFourEnabled = true

        model.start(atMeasureIndex: 2)

        let start = harness.clickEngine.starts.last
        XCTAssertEqual(model.currentMeasureIndex, 2)
        XCTAssertEqual(start?.startMeasureIndex, 2)
        XCTAssertEqual(start?.countInBeats, 4)
    }

    func testTapMeasureIgnoresInvalidIndex() {
        let harness = ModelHarness()
        let model = harness.model

        model.start(atMeasureIndex: 99)

        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(harness.clickEngine.starts.isEmpty)
    }

    func testTapMeasureWhilePlayingRestartsAtTappedMeasure() async {
        let harness = ModelHarness()
        let model = harness.model
        model.start()
        harness.clickEngine.starts.last?.onBeat(0, 0, 1, false)
        await Task.yield()

        model.start(atMeasureIndex: 2)

        let restart = harness.clickEngine.starts.last
        XCTAssertEqual(harness.clickEngine.starts.count, 2)
        XCTAssertEqual(model.currentMeasureIndex, 2)
        XCTAssertEqual(model.currentBeat, -1)
        XCTAssertEqual(restart?.startMeasureIndex, 2)
    }
}

@MainActor
final class TapTempoTests: XCTestCase {
    func testTapTempoAveragesIntervalsAndUpdatesText() {
        var fakeNow = Date(timeIntervalSince1970: 1_000)
        let harness = ModelHarness(now: { fakeNow })
        let model = harness.model

        model.tapTempo()
        XCTAssertEqual(model.tapTempoText, "TAP")

        fakeNow = fakeNow.addingTimeInterval(0.5)
        model.tapTempo()
        XCTAssertEqual(model.bpm, 120)
        XCTAssertEqual(model.tapTempoText, "120")

        fakeNow = fakeNow.addingTimeInterval(1.0)
        model.tapTempo()
        XCTAssertEqual(model.bpm, 80)
        XCTAssertEqual(model.tapTempoText, "80")
    }

    func testTapTempoClampsBPM() {
        var fakeNow = Date(timeIntervalSince1970: 1_000)
        let harness = ModelHarness(now: { fakeNow })
        let model = harness.model

        model.tapTempo()
        fakeNow = fakeNow.addingTimeInterval(0.05)
        model.tapTempo()
        XCTAssertEqual(model.bpm, 300)

        model.stop()
        let slowHarness = ModelHarness(now: { fakeNow })
        let slowModel = slowHarness.model
        slowModel.tapTempo()
        fakeNow = fakeNow.addingTimeInterval(10)
        slowModel.tapTempo()
        XCTAssertEqual(slowModel.bpm, 20)
    }

    func testTapTempoResetReturnsTextToTap() async throws {
        var fakeNow = Date(timeIntervalSince1970: 1_000)
        let harness = ModelHarness(now: { fakeNow }, tapResetDelay: .milliseconds(1))
        let model = harness.model

        model.tapTempo()
        fakeNow = fakeNow.addingTimeInterval(0.5)
        model.tapTempo()
        XCTAssertEqual(model.tapTempoText, "120")

        try await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(model.tapTempoText, "TAP")
    }
}

@MainActor
final class SongLibraryPersistenceTests: XCTestCase {
    func testLoadsPersistedLibraryAndCurrentSong() throws {
        let userDefaults = makeUserDefaults()
        let currentID = UUID()
        let otherID = UUID()
        let library = PersistedSongLibrary(
            currentSongID: currentID,
            songs: [
                Song(id: otherID, name: "Other", bpm: 90, startMeasureNumber: 1, sequence: [signature(4, 4)]),
                Song(id: currentID, name: "Current", bpm: 150, startMeasureNumber: 12, sequence: [signature(5, 8)])
            ]
        )
        try store(library, in: userDefaults, key: "metro.songLibrary.v1")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertEqual(model.currentSongID, currentID)
        XCTAssertEqual(model.currentSongName, "Current")
        XCTAssertEqual(model.bpm, 150)
        XCTAssertEqual(model.startMeasureNumber, 12)
        XCTAssertEqual(model.sequence.map(\.label), ["5/8"])
    }

    func testFallsBackWhenCurrentSongIDIsMissing() throws {
        let userDefaults = makeUserDefaults()
        let songID = UUID()
        let library = PersistedSongLibrary(
            currentSongID: UUID(),
            songs: [
                Song(id: songID, name: "Only", bpm: 100, startMeasureNumber: 2, sequence: [signature(3, 4)])
            ]
        )
        try store(library, in: userDefaults, key: "metro.songLibrary.v1")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertEqual(model.currentSongID, songID)
        XCTAssertEqual(model.currentSongName, "Only")
    }

    func testSanitizesPersistedSongsAndIncludesBuiltInOnce() throws {
        let userDefaults = makeUserDefaults()
        let library = PersistedSongLibrary(
            currentSongID: UUID(),
            songs: [
                Song(
                    name: "   ",
                    bpm: 999,
                    startMeasureNumber: -5,
                    sequence: [
                        TimeSignature(numerator: 0, denominator: 4),
                        TimeSignature(numerator: 7, denominator: 8, grouping: [5, 2])
                    ],
                    countInFourFourEnabled: nil
                ),
                ForestForTheTreesSong.measure446To472
            ]
        )
        try store(library, in: userDefaults, key: "metro.songLibrary.v1")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertEqual(model.songs[0].name, "Song 1")
        XCTAssertEqual(model.songs[0].bpm, 300)
        XCTAssertEqual(model.songs[0].startMeasureNumber, 0)
        XCTAssertEqual(model.songs[0].sequence.map(\.label), ["7/8"])
        XCTAssertNil(model.songs[0].sequence[0].grouping)
        XCTAssertEqual(model.songs.filter { $0.id == ForestForTheTreesSong.measure446To472ID }.count, 1)
    }

    func testLoadsEditedBuiltInSongWithoutOverwritingIt() throws {
        let userDefaults = makeUserDefaults()
        var editedBuiltIn = ForestForTheTreesSong.measure446To472
        editedBuiltIn.name = "Forest Practice Edit"
        editedBuiltIn.bpm = 132
        editedBuiltIn.startMeasureNumber = 500
        editedBuiltIn.sequence = [signature(5, 8)]
        let library = PersistedSongLibrary(
            currentSongID: editedBuiltIn.id,
            songs: [editedBuiltIn]
        )
        try store(library, in: userDefaults, key: "metro.songLibrary.v1")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertTrue(model.canResetCurrentSongToBuiltIn)
        XCTAssertEqual(model.currentSongName, "Forest Practice Edit")
        XCTAssertEqual(model.bpm, 132)
        XCTAssertEqual(model.startMeasureNumber, 500)
        XCTAssertEqual(model.sequence.map(\.label), ["5/8"])
    }

    func testResetsCurrentBuiltInSongToHardcodedVersion() throws {
        let userDefaults = makeUserDefaults()
        var editedBuiltIn = ForestForTheTreesSong.measure446To472
        editedBuiltIn.name = "Forest Practice Edit"
        editedBuiltIn.bpm = 132
        editedBuiltIn.startMeasureNumber = 500
        editedBuiltIn.sequence = [signature(5, 8)]
        let library = PersistedSongLibrary(
            currentSongID: editedBuiltIn.id,
            songs: [editedBuiltIn]
        )
        try store(library, in: userDefaults, key: "metro.songLibrary.v1")
        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        model.resetCurrentSongToBuiltIn()

        let hardcoded = ForestForTheTreesSong.measure446To472
        XCTAssertEqual(model.currentSongID, hardcoded.id)
        XCTAssertEqual(model.currentSongName, hardcoded.name)
        XCTAssertEqual(model.bpm, hardcoded.bpm)
        XCTAssertEqual(model.startMeasureNumber, hardcoded.startMeasureNumber)
        XCTAssertEqual(model.sequence.map(\.label), hardcoded.sequence.map(\.label))
        XCTAssertEqual(model.sequence.compactMap(\.validGrouping), hardcoded.sequence.compactMap(\.validGrouping))
        XCTAssertEqual(model.songs.filter { $0.id == ForestForTheTreesSong.measure446To472ID }.count, 1)
    }

    func testBuiltInSongsDefaultToReadOnly() throws {
        let userDefaults = makeUserDefaults()
        var editedBuiltIn = ForestForTheTreesSong.measure446To472
        editedBuiltIn.isReadOnly = nil
        let library = PersistedSongLibrary(
            currentSongID: editedBuiltIn.id,
            songs: [editedBuiltIn]
        )
        try store(library, in: userDefaults, key: "metro.songLibrary.v1")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertTrue(model.isCurrentSongReadOnly)
        XCTAssertTrue(model.songs.first { $0.id == ForestForTheTreesSong.measure105To136ID }?.readOnly ?? false)
        XCTAssertTrue(model.songs.first { $0.id == ForestForTheTreesSong.measure446To472ID }?.readOnly ?? false)
    }

    func testReadOnlySongRejectsCompositionEditsUntilUnlocked() {
        let harness = ModelHarness()
        let model = harness.model
        let originalName = model.currentSongName
        let originalBPM = model.bpm
        let originalStartMeasure = model.startMeasureNumber
        let originalSequence = model.sequence

        model.setCurrentSongReadOnly(true)

        model.currentSongName = "Locked Edit"
        model.bpm = 160
        model.startMeasureNumber = 12
        model.isCountInFourFourEnabled = true
        model.isLoopRangeEnabled = true
        model.updateLoopStartMeasureNumber(2)
        model.updateLoopEndMeasureNumber(2)
        XCTAssertFalse(model.insertMeasure(at: 0, numerator: 5, denominator: 8))
        XCTAssertFalse(model.duplicateMeasure(at: 1))
        XCTAssertFalse(model.updateMeasure(model.sequence[0], numerator: 6, denominator: 8))
        model.updateGrouping(for: model.sequence[0], grouping: [3, 2, 2])
        model.deleteMeasure(model.sequence[0])
        model.tapTempo()

        XCTAssertEqual(model.currentSongName, originalName)
        XCTAssertEqual(model.bpm, originalBPM)
        XCTAssertEqual(model.startMeasureNumber, originalStartMeasure)
        XCTAssertTrue(model.isCountInFourFourEnabled)
        XCTAssertTrue(model.isLoopRangeEnabled)
        XCTAssertEqual(model.loopStartIndex, 1)
        XCTAssertEqual(model.loopEndIndex, 1)
        XCTAssertEqual(model.sequence, originalSequence)
        XCTAssertEqual(model.tapTempoText, "TAP")
        XCTAssertTrue(model.isCurrentSongReadOnly)
        XCTAssertEqual(model.currentSong.loopRange, PersistedLoopRange(isEnabled: true, startIndex: 1, endIndex: 1))
        XCTAssertEqual(model.currentSong.countInFourFourEnabled, true)

        model.setCurrentSongReadOnly(false)

        model.currentSongName = "Unlocked Edit"
        model.bpm = 160

        XCTAssertEqual(model.currentSongName, "Unlocked Edit")
        XCTAssertEqual(model.bpm, 160)
    }

    func testDuplicateOfReadOnlySongIsEditable() {
        let harness = ModelHarness()
        let model = harness.model
        model.setCurrentSongReadOnly(true)

        model.duplicateCurrentSong()

        XCTAssertFalse(model.isCurrentSongReadOnly)
        model.currentSongName = "Editable Copy"
        XCTAssertEqual(model.currentSongName, "Editable Copy")
    }

    func testFallsBackToDefaultSongWhenStoredSongsAreInvalid() throws {
        let userDefaults = makeUserDefaults()
        let library = PersistedSongLibrary(
            currentSongID: UUID(),
            songs: [
                Song(name: "", bpm: 0, startMeasureNumber: 0, sequence: [TimeSignature(numerator: 0, denominator: 0)])
            ]
        )
        try store(library, in: userDefaults, key: "metro.songLibrary.v1")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertEqual(model.currentSongName, "Song 1")
        XCTAssertEqual(model.bpm, 120)
        XCTAssertEqual(model.sequence.map(\.label), ["7/8", "4/4", "3/4"])
    }

    func testMigratesPersistedComposition() throws {
        let userDefaults = makeUserDefaults()
        let composition = PersistedComposition(
            startMeasureNumber: 446,
            sequence: [signature(5, 8)],
            loopRange: PersistedLoopRange(isEnabled: true, startIndex: 0, endIndex: 0)
        )
        try store(composition, in: userDefaults, key: "metro.composition.v2")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertEqual(model.currentSongName, "Song 1")
        XCTAssertEqual(model.startMeasureNumber, 446)
        XCTAssertEqual(model.sequence.map(\.label), ["5/8"])
        XCTAssertTrue(model.isLoopRangeEnabled)
    }

    func testMigratesLegacySequence() throws {
        let userDefaults = makeUserDefaults()
        try store([signature(2, 4), signature(3, 8)], in: userDefaults, key: "metro.sequence.v1")

        let model = MetronomeModel(clickEngine: FakeClickEngine(), userDefaults: userDefaults)

        XCTAssertEqual(model.currentSongName, "Song 1")
        XCTAssertEqual(model.bpm, 120)
        XCTAssertEqual(model.startMeasureNumber, 1)
        XCTAssertEqual(model.sequence.map(\.label), ["2/4", "3/8"])
    }
}

private final class ModelHarness {
    let clickEngine = FakeClickEngine()
    let userDefaults: UserDefaults
    let model: MetronomeModel

    @MainActor
    init(
        now: @escaping () -> Date = Date.init,
        tapResetDelay: Duration = .seconds(60),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        userDefaults = makeUserDefaults(file: file, line: line)
        model = MetronomeModel(
            clickEngine: clickEngine,
            userDefaults: userDefaults,
            now: now,
            tapResetDelay: tapResetDelay
        )
    }
}

private final class FakeClickEngine: ClickEngineProtocol {
    struct StartCall {
        let bpm: Int
        let sequence: [TimeSignature]
        let startMeasureIndex: Int
        let startBeat: Int
        let loopStartIndex: Int
        let loopEndIndex: Int
        let loopCount: Int
        let countInBeats: Int
        let onBeat: (Int, Int, Int, Bool) -> Void
    }

    private(set) var starts: [StartCall] = []
    private(set) var stopCount = 0

    func start(
        bpm: Int,
        sequence: [TimeSignature],
        startMeasureIndex: Int,
        startBeat: Int,
        loopStartIndex: Int,
        loopEndIndex: Int,
        loopCount: Int,
        countInBeats: Int,
        onBeat: @escaping (Int, Int, Int, Bool) -> Void
    ) {
        starts.append(StartCall(
            bpm: bpm,
            sequence: sequence,
            startMeasureIndex: startMeasureIndex,
            startBeat: startBeat,
            loopStartIndex: loopStartIndex,
            loopEndIndex: loopEndIndex,
            loopCount: loopCount,
            countInBeats: countInBeats,
            onBeat: onBeat
        ))
    }

    func stop() {
        stopCount += 1
    }
}

private func signature(_ numerator: Int, _ denominator: Int, grouping: [Int]? = nil) -> TimeSignature {
    TimeSignature(numerator: numerator, denominator: denominator, grouping: grouping)
}

private func makeUserDefaults(file: StaticString = #filePath, line: UInt = #line) -> UserDefaults {
    let suiteName = "IrregularMeasureMetronomeTests.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        XCTFail("Could not create UserDefaults suite", file: file, line: line)
        return .standard
    }
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
}

private func store<T: Encodable>(
    _ value: T,
    in userDefaults: UserDefaults,
    key: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    do {
        userDefaults.set(try JSONEncoder().encode(value), forKey: key)
    } catch {
        XCTFail("Could not encode test value: \(error)", file: file, line: line)
        throw error
    }
}
