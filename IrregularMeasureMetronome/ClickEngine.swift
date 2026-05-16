import AVFoundation
import Foundation

final class ClickEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let schedulerQueue = DispatchQueue(label: "metro.click-engine.scheduler")

    private var format: AVAudioFormat?
    private var accentedBuffer: AVAudioPCMBuffer?
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
        loopCount: Int,
        onBeat: @escaping (Int, Int, Int) -> Void
    ) {
        guard !sequence.isEmpty else { return }
        prepare()

        schedulerQueue.async { [weak self] in
            guard let self else { return }
            self.stopSchedulingOnQueue()
            self.scheduleGeneration += 1
            let generation = self.scheduleGeneration
            let playback = PlaybackState(
                bpm: bpm,
                sequence: sequence,
                measureIndex: min(max(0, startMeasureIndex), sequence.count - 1),
                beat: max(0, startBeat),
                loopCount: max(1, loopCount),
                onBeat: onBeat
            )

            self.player.stop()
            self.player.play()
            self.pendingScheduledBeats = 0
            self.nextCallbackOffset = 0
            self.callbackStartTime = .now() + .milliseconds(20)
            var state = playback.normalized()
            self.fillQueue(state: &state, generation: generation)

            let timer = DispatchSource.makeTimerSource(queue: self.schedulerQueue)
            timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self, generation == self.scheduleGeneration else { return }
                self.fillQueue(state: &state, generation: generation)
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

    private func fillQueue(state: inout PlaybackState, generation: Int) {
        guard generation == scheduleGeneration else { return }
        while pendingScheduledBeats < maxQueuedBeats {
            scheduleBeat(state: &state, generation: generation)
        }
    }

    private func scheduleBeat(state: inout PlaybackState, generation: Int) {
        guard let format,
              let accentedBuffer,
              let regularBuffer
        else { return }

        let measure = state.sequence[state.measureIndex]
        let intervalSeconds = (60 / Double(state.bpm)) * (4 / Double(measure.denominator))
        let intervalFrames = AVAudioFrameCount(max(1, (intervalSeconds * format.sampleRate).rounded()))
        let clickBuffer = state.beat == 0 ? accentedBuffer : regularBuffer
        let silenceFrameCount = max(1, intervalFrames - clickBuffer.frameLength)
        let silenceBuffer = silenceBuffer(frameCount: silenceFrameCount, format: format)
        let beatMeasureIndex = state.measureIndex
        let beat = state.beat
        let beatLoopCount = state.loopCount
        let onBeat = state.onBeat
        let callbackDeadline = callbackStartTime + .nanoseconds(Int(nextCallbackOffset * 1_000_000_000))

        pendingScheduledBeats += 1
        player.scheduleBuffer(clickBuffer, at: nil, options: [], completionHandler: nil)
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
                    onBeat(beatMeasureIndex, beat, beatLoopCount)
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

private struct PlaybackState {
    let bpm: Int
    let sequence: [TimeSignature]
    var measureIndex: Int
    var beat: Int
    var loopCount: Int
    let onBeat: (Int, Int, Int) -> Void

    func normalized() -> PlaybackState {
        var copy = self
        let measure = copy.sequence[copy.measureIndex]
        if copy.beat >= measure.numerator {
            copy.beat = 0
        }
        return copy
    }

    mutating func advancePastCurrentBeat() {
        let measure = sequence[measureIndex]
        beat += 1
        if beat >= measure.numerator {
            beat = 0
            measureIndex += 1
            if measureIndex >= sequence.count {
                measureIndex = 0
                loopCount += 1
            }
        }
    }
}
