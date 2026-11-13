import AVFoundation

/// Speak Away's own short sounds while a session is on, synthesized when first needed (no audio files): a rising
/// blip when a dictation starts and a falling one when it stops. The same tones as on the Mac.
@MainActor
final class SessionSounds {
    enum Cue { case start, stop }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.35
        buffers = [
            .start: tone([(660, 0.055), (990, 0.08)]),
            .stop: tone([(880, 0.055), (587, 0.09)]),
        ]
    }

    func play(_ cue: Cue) {
        guard let buffer = buffers[cue] else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// Frees the audio engine when the session ends.
    func stop() {
        player.stop()
        engine.stop()
    }

    /// Notes in sequence, each a sine with a soft attack and an exponential tail so nothing clicks.
    private func tone(_ notes: [(freq: Double, seconds: Double)]) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let total = notes.reduce(0) { $0 + Int($1.seconds * rate) } + Int(0.06 * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total))!
        buffer.frameLength = AVAudioFrameCount(total)
        let out = buffer.floatChannelData![0]
        var i = 0
        for note in notes {
            let n = Int(note.seconds * rate)
            for k in 0..<n {
                let t = Double(k) / rate
                let attack = min(1, t / 0.004)
                let decay = exp(-t * 18)
                let s = sin(2 * .pi * note.freq * t) + 0.25 * sin(4 * .pi * note.freq * t)
                out[i] = Float(s * attack * decay * 0.5)
                i += 1
            }
        }
        while i < total { out[i] = 0; i += 1 }
        return buffer
    }
}
