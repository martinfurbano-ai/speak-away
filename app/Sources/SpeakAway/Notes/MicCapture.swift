import AVFoundation

/// The "Me" track: the default microphone through its own AVAudioEngine, never the dictation Recorder's.
/// If the input device changes in the middle of a call (AirPods connect, a USB mic is unplugged) the engine
/// is rebuilt on the new device; the hole is filled with silence by TrackBuffer.
final class MicCapture {
    enum Failure: Error { case noMicrophone }

    private let onSamples: @Sendable ([Float]) -> Void
    private var engine: AVAudioEngine?
    private var observer: NSObjectProtocol?
    private let resampler = AudioResampler()

    init(onSamples: @escaping @Sendable ([Float]) -> Void) {
        self.onSamples = onSamples
    }

    func start() throws {
        try build()
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] note in
            guard let self, let changed = note.object as? AVAudioEngine, changed === self.engine else { return }
            self.teardown()
            try? self.build()
        }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        teardown()
    }

    private func build() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw Failure.noMicrophone }
        let resampler = self.resampler
        let sink = onSamples
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            let samples = resampler.convert(buffer)
            if !samples.isEmpty { sink(samples) }
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    private func teardown() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}
