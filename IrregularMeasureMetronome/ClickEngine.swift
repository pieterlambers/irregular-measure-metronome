import AVFoundation
import Foundation

protocol ClickEngineProtocol: AnyObject {
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
    )

    func stop()
}

final class ClickEngine: ClickEngineProtocol {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let schedulerQueue = DispatchQueue(label: "metro.click-engine.scheduler")

    private var format: AVAudioFormat?
    private var accentedBuffer: AVAudioPCMBuffer?
    private var subaccentedBuffer: AVAudioPCMBuffer?
    private var regularBuffer: AVAudioPCMBuffer?
    private var silenceBuffers: [AVAudioFrameCount: AVAudioPCMBuffer] = [:]
    private var schedulerTimer: DispatchSourceTimer?
    private var pendingScheduledBeats = 0
    private var scheduleGeneration = 0
    private var nextCallbackOffset: TimeInterval = 0
    private var callbackStartTime = DispatchTime.now()

    private let maxQueuedBeats = 12

    func prepare() {
        let format = self.format ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        self.format = format

        if accentedBuffer == nil {
            accentedBuffer = Self.makeClickBuffer(frequency: 1800, gain: 0.42, format: format)
        }
        if subaccentedBuffer == nil {
            subaccentedBuffer = Self.makeClickBuffer(frequency: 1450, gain: 0.34, format: format)
        }
        if regularBuffer == nil {
            regularBuffer = Self.makeClickBuffer(frequency: 1100, gain: 0.28, format: format)
        }

        if player.engine == nil {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning {
            try? engine.start()
        }
        if !player.isPlaying {
            player.play()
        }
    }

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
        guard !sequence.isEmpty else { return }
        prepare()

        schedulerQueue.async { [weak self] in
            guard let self else { return }
            self.stopSchedulingOnQueue()
            self.scheduleGeneration += 1
            let generation = self.scheduleGeneration
            let playback = PlaybackCursor(
                bpm: bpm,
                sequence: sequence,
                startMeasureIndex: startMeasureIndex,
                startBeat: startBeat,
                loopStartIndex: loopStartIndex,
                loopEndIndex: loopEndIndex,
                loopCount: loopCount,
                countInBeats: countInBeats
            )

            self.player.stop()
            self.player.play()
            self.pendingScheduledBeats = 0
            self.nextCallbackOffset = 0
            self.callbackStartTime = .now() + .milliseconds(20)
            var state = playback
            self.fillQueue(state: &state, generation: generation, onBeat: onBeat)

            let timer = DispatchSource.makeTimerSource(queue: self.schedulerQueue)
            timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self, generation == self.scheduleGeneration else { return }
                self.fillQueue(state: &state, generation: generation, onBeat: onBeat)
            }
            self.schedulerTimer = timer
            timer.resume()
        }
    }

    func stop() {
        schedulerQueue.async { [weak self] in
            guard let self else { return }
            self.stopSchedulingOnQueue()
            self.scheduleGeneration += 1
            self.player.stop()
        }
    }

    private func stopSchedulingOnQueue() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
        pendingScheduledBeats = 0
    }

    private func fillQueue(
        state: inout PlaybackCursor,
        generation: Int,
        onBeat: @escaping (Int, Int, Int, Bool) -> Void
    ) {
        guard generation == scheduleGeneration else { return }
        while pendingScheduledBeats < maxQueuedBeats {
            scheduleBeat(state: &state, generation: generation, onBeat: onBeat)
        }
    }

    private func scheduleBeat(
        state: inout PlaybackCursor,
        generation: Int,
        onBeat: @escaping (Int, Int, Int, Bool) -> Void
    ) {
        guard let format,
              let accentedBuffer,
              let subaccentedBuffer,
              let regularBuffer
        else { return }

        let measure = state.sequence[state.measureIndex]
        let isCountIn = state.isCountingIn
        let denominator = isCountIn ? 4 : measure.denominator
        let intervalSeconds = (60 / Double(state.bpm)) * (4 / Double(denominator))
        let intervalFrames = AVAudioFrameCount(max(1, (intervalSeconds * format.sampleRate).rounded()))
        let scheduledBeat = isCountIn ? state.countInBeat : state.beat
        let isMainAccent = scheduledBeat == 0 || (!isCountIn && measure.isSubaccented(beat: scheduledBeat))
        let clickBuffer: AVAudioPCMBuffer?
        if scheduledBeat == 0 {
            clickBuffer = accentedBuffer
        } else if isCountIn {
            clickBuffer = regularBuffer
        } else if measure.denominator == 8 {
            clickBuffer = isMainAccent ? subaccentedBuffer : nil
        } else if measure.isSubaccented(beat: scheduledBeat) {
            clickBuffer = subaccentedBuffer
        } else {
            clickBuffer = regularBuffer
        }
        let silenceFrameCount = max(1, intervalFrames - (clickBuffer?.frameLength ?? 0))
        let silenceBuffer = silenceBuffer(frameCount: silenceFrameCount, format: format)
        let beatMeasureIndex = state.measureIndex
        let beat = scheduledBeat
        let beatLoopCount = state.loopCount
        let callbackDeadline = callbackStartTime + .nanoseconds(Int(nextCallbackOffset * 1_000_000_000))

        pendingScheduledBeats += 1
        if let clickBuffer {
            player.scheduleBuffer(clickBuffer, at: nil, options: [], completionHandler: nil)
        }
        player.scheduleBuffer(silenceBuffer, at: nil, options: []) { [weak self] in
            self?.schedulerQueue.async { [weak self] in
                guard let self, generation == self.scheduleGeneration else { return }
                self.pendingScheduledBeats = max(0, self.pendingScheduledBeats - 1)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: callbackDeadline) { [weak self] in
            self?.schedulerQueue.async { [weak self] in
                guard let self, generation == self.scheduleGeneration else { return }
                DispatchQueue.main.async {
                    onBeat(beatMeasureIndex, beat, beatLoopCount, isCountIn)
                }
            }
        }

        nextCallbackOffset += intervalSeconds
        state.advancePastCurrentBeat()
    }

    private func silenceBuffer(frameCount: AVAudioFrameCount, format: AVAudioFormat) -> AVAudioPCMBuffer {
        if let buffer = silenceBuffers[frameCount] {
            return buffer
        }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        silenceBuffers[frameCount] = buffer
        return buffer
    }

    private static func makeClickBuffer(
        frequency: Double,
        gain: Float,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer {
        let duration = 0.07
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / format.sampleRate
            let phase = 2 * Double.pi * frequency * t
            let envelope = max(0.001, exp(-70 * t))
            channel[frame] = sin(Float(phase)) * gain * Float(envelope)
        }

        return buffer
    }
}

struct PlaybackCursor {
    let bpm: Int
    let sequence: [TimeSignature]
    var measureIndex: Int
    var beat: Int
    let loopStartIndex: Int
    let loopEndIndex: Int
    var loopCount: Int
    var countInBeatsRemaining: Int
    var countInBeat = 0

    var isCountingIn: Bool {
        countInBeatsRemaining > 0
    }

    init(
        bpm: Int,
        sequence: [TimeSignature],
        startMeasureIndex: Int,
        startBeat: Int,
        loopStartIndex: Int,
        loopEndIndex: Int,
        loopCount: Int,
        countInBeats: Int
    ) {
        let lastIndex = sequence.count - 1
        let clampedLoopStart = min(max(0, loopStartIndex), lastIndex)
        let clampedLoopEnd = min(max(0, loopEndIndex), lastIndex)
        self.bpm = bpm
        self.sequence = sequence
        self.loopStartIndex = min(clampedLoopStart, clampedLoopEnd)
        self.loopEndIndex = max(clampedLoopStart, clampedLoopEnd)
        self.loopCount = max(1, loopCount)
        self.countInBeatsRemaining = max(0, countInBeats)
        self.measureIndex = min(max(self.loopStartIndex, startMeasureIndex), self.loopEndIndex)
        self.beat = max(0, startBeat)
        self.countInBeat = 0

        let measure = sequence[self.measureIndex]
        if self.beat >= measure.numerator {
            self.beat = 0
        }
    }

    mutating func advancePastCurrentBeat() {
        if countInBeatsRemaining > 0 {
            countInBeatsRemaining -= 1
            countInBeat = countInBeatsRemaining > 0 ? countInBeat + 1 : 0
            return
        }

        let measure = sequence[measureIndex]
        beat += 1
        if beat >= measure.numerator {
            beat = 0
            measureIndex += 1
            if measureIndex > loopEndIndex {
                measureIndex = loopStartIndex
                loopCount += 1
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
