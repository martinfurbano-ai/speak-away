import AVFoundation
import SpeakAwayCore

/// The door between the microphone and the transcriber. Closed, every buffer is dropped on the spot
/// (nothing is stored, nothing is measured). Open, buffers go to the transcriber and are measured, so
/// the session knows how long the dictation was, how loud, and how loud it is right now.
final class CaptureGate {
    private let lock = NSLock()
    private var sink: ((AVAudioPCMBuffer) -> Void)?
    private var stats = CaptureStats()
    private var level = 0.0

    var isOpen: Bool {
        lock.lock(); defer { lock.unlock() }
        return sink != nil
    }

    /// Voice loudness for the level bars, 0...1.
    var currentLevel: Double {
        lock.lock(); defer { lock.unlock() }
        return level
    }

    func open(_ sink: @escaping (AVAudioPCMBuffer) -> Void) {
        lock.lock()
        self.sink = sink
        stats = CaptureStats()
        level = 0
        lock.unlock()
    }

    /// Closes the gate and returns what was measured while it was open.
    @discardableResult
    func close() -> CaptureStats {
        lock.lock()
        sink = nil
        level = 0
        let result = stats
        lock.unlock()
        return result
    }

    /// Called for every buffer from the input, on the audio thread.
    func offer(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); let sink = self.sink; lock.unlock()
        guard let sink else { return }
        let measured = Self.measure(buffer)
        lock.lock()
        stats = stats.adding(frames: Int(buffer.frameLength), sampleRate: buffer.format.sampleRate, peak: measured.peak)
        level = LevelMeter.level(rms: measured.rms)
        lock.unlock()
        sink(buffer)
    }

    /// RMS and peak of the first channel, as 0...1 samples.
    private static func measure(_ buffer: AVAudioPCMBuffer) -> (rms: Double, peak: Float) {
        let count = Int(buffer.frameLength)
        guard count > 0 else { return (0, 0) }
        if let channel = buffer.floatChannelData?[0] {
            let samples = UnsafeBufferPointer(start: channel, count: count)
            return (LevelMeter.rms(of: samples), samples.reduce(Float(0)) { max($0, abs($1)) })
        }
        if let channel = buffer.int16ChannelData?[0] {
            let scaled = (0..<count).map { Float(channel[$0]) / Float(Int16.max) }
            return (LevelMeter.rms(of: scaled), scaled.reduce(Float(0)) { max($0, abs($1)) })
        }
        return (0, 0)
    }
}
