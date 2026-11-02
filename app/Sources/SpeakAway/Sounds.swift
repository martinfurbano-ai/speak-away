import AVFoundation

/// Speak Away's own short sounds, synthesized at launch (no audio files): a rising blip to start,
/// a falling one to stop and a soft tick when the text lands. Off with Settings.sounds.
@MainActor
final class Sounds {
    enum Cue { case start, stop, paste, achievement }

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
            .paste: tone([(1320, 0.035)]),
            .achievement: tone([(784, 0.07), (988, 0.07), (1319, 0.14)]),
        ]
    }

    func play(_ cue: Cue) {
        guard Settings.sounds, let buffer = buffers[cue] else { return }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
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
