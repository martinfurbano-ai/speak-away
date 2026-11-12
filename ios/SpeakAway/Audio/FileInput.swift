import AVFoundation

/// A recorded file played into the session as if it were the microphone. The app uses it to check itself
/// (`--self-test`), so the same path as a real dictation runs without anyone speaking.
final class FileInput: AudioInput {
    let needsMicrophone = false
    var onEvent: ((AudioInputEvent) -> Void)?

    private let url: URL
    private let speed: Double
    private let lock = NSLock()
    private var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    private var playing: Task<Void, Never>?

    /// `speed` is how many times faster than real time the file is delivered.
    init(url: URL, speed: Double = 1) {
        self.url = url
        self.speed = max(0.1, speed)
    }

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        lock.withLock { self.onBuffer = onBuffer }
    }

    /// Delivers the whole file (this input's own, or `other`) at the chosen speed, then returns.
    func play(_ other: URL? = nil) async throws {
        let file = try AVAudioFile(forReading: other ?? url)
        let format = file.processingFormat
        let chunk: AVAudioFrameCount = 4096
        let pause = Double(chunk) / format.sampleRate / speed
        let task = Task { [weak self] in
            while file.framePosition < file.length, !Task.isCancelled {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return }
                do { try file.read(into: buffer, frameCount: chunk) } catch { return }
                if buffer.frameLength == 0 { return }
                let sink = self?.lock.withLock { self?.onBuffer }
                sink?(buffer)
                try? await Task.sleep(for: .seconds(pause))
            }
        }
        lock.withLock { playing = task }
        await task.value
    }

    func stop() {
        lock.withLock {
            playing?.cancel()
            playing = nil
            onBuffer = nil
        }
    }
}
