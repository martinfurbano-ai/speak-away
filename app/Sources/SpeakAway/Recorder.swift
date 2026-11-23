import AVFoundation

/// Records the current microphone as 16 kHz mono floats, the format Whisper wants.
/// A fresh engine per recording, so switching to AirPods between dictations just works.
final class Recorder {
    enum Failure: Error { case noMicrophone }

    static let sampleRate = 16_000
    var onLevel: ((Float) -> Void)?

    private var engine: AVAudioEngine?
    private var samples: [Float] = []
    private let lock = NSLock()

    func start() throws {
        let engine = AVAudioEngine()
        Microphones.apply(Settings.microphone, to: engine)
        let input = engine.inputNode
        // The hardware format of the device in use. outputFormat can still describe the previous
        // device (AirPods at 24 kHz while the Mac mic runs at 48 kHz): tapping with it crashes, and
        // converting with the wrong rate speeds the voice up or slows it down, which garbles Whisper.
        let inFormat = input.inputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else { throw Failure.noMicrophone }

        lock.lock(); samples = []; lock.unlock()
        // Rebuilds its converter whenever a buffer arrives in another format, so a device switch
        // mid-dictation keeps the right speed.
        let resampler = AudioResampler()
        input.installTap(onBus: 0, bufferSize: 2048, format: inFormat) { [weak self] buffer, _ in
            self?.consume(resampler.convert(buffer))
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    func stop() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine?.reset()   // lets go of the input device, so the orange microphone dot turns off
        engine = nil
        lock.lock(); defer { lock.unlock() }
        return samples
    }

    private func consume(_ chunk: [Float]) {
        guard !chunk.isEmpty else { return }
        let rms = sqrt(chunk.reduce(0) { $0 + $1 * $1 } / Float(chunk.count))
        lock.lock(); samples.append(contentsOf: chunk); lock.unlock()
        onLevel?(min(1, rms * 25))
    }
}
