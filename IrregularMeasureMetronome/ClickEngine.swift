import AVFoundation

final class ClickEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var accentedBuffer: AVAudioPCMBuffer?
    private var regularBuffer: AVAudioPCMBuffer?

    func prepare() {
        guard !engine.isRunning else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        accentedBuffer = Self.makeClickBuffer(frequency: 1800, gain: 0.42, format: format)
        regularBuffer = Self.makeClickBuffer(frequency: 1100, gain: 0.28, format: format)

        if player.engine == nil {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
        if !player.isPlaying {
            player.play()
        }
    }

    func playClick(accented: Bool) {
        prepare()
        let buffer = accented ? accentedBuffer : regularBuffer
        guard let buffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
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
