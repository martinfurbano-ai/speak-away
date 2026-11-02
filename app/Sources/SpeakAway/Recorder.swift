import AVFoundation

/// Records the current microphone as 16 kHz mono floats, the format Whisper wants.
/// A fresh engine per recording, so switching to AirPods between dictations just works.
final class Recorder {
    enum Failure: Error { case noMicrophone, noConverter }

    static let sampleRate = 16_000
    var onLevel: ((Float) -> Void)?

    private var engine: AVAudioEngine?
    private var samples: [Float] = []
    private let lock = NSLock()

    func start() throws {
        let engine = AVAudioEngine()
        Microphones.apply(Settings.microphone, to: engine)
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else { throw Failure.noMicrophone }
        guard
            let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(Recorder.sampleRate), channels: 1, interleaved: false),
            let converter = AVAudioConverter(from: inFormat, to: outFormat)
        else { throw Failure.noConverter }

        lock.lock(); samples = []; lock.unlock()
        input.installTap(onBus: 0, bufferSize: 2048, format: inFormat) { [weak self] buffer, _ in
            self?.consume(buffer, converter: converter, outFormat: outFormat)
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    func stop() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        lock.lock(); defer { lock.unlock() }
        return samples
    }

    private func consume(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outFormat: AVAudioFormat) {
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.floatChannelData?[0], out.frameLength > 0 else { return }
        let chunk = Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
        let rms = sqrt(chunk.reduce(0) { $0 + $1 * $1 } / Float(chunk.count))
        lock.lock(); samples.append(contentsOf: chunk); lock.unlock()
        onLevel?(min(1, rms * 25))
    }
}
