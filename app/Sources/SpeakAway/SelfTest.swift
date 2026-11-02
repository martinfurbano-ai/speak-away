import AVFoundation
import Foundation
import SpeakAwayCore

/// `SpeakAway --transcribe file.wav`: runs the same model, silence gate and cleanup as dictation,
/// prints the text and exits. Used to check a build without touching the keyboard.
@MainActor
enum SelfTest {
    static func run(path: String) -> Never {
        let engine = Engine()
        Task {
            do {
                let audio = try load(path)
                engine.prepare()
                while !engine.isReady {
                    if case .failed(let message) = engine.state { fail(message) }
                    try await Task.sleep(nanoseconds: 300_000_000)
                }
                let verdict = SpeechGate.check(audio, sampleRate: Recorder.sampleRate)
                guard verdict == .speech else {
                    print("GATE \(verdict)")
                    exit(0)
                }
                let started = Date()
                let text = SpeechGate.clean(try await engine.transcribe(audio))
                print(String(format: "TEXT (%.1f s): %@", Date().timeIntervalSince(started), text))
                exit(0)
            } catch {
                fail(error.localizedDescription)
            }
        }
        RunLoop.main.run()
        exit(0)
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("ERROR \(message)\n".utf8))
        exit(1)
    }

    private static func load(_ path: String) throws -> [Float] {
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(Recorder.sampleRate), channels: 1, interleaved: false)!
        let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: input)
        let converter = AVAudioConverter(from: file.processingFormat, to: target)!
        let capacity = AVAudioFrameCount(Double(input.frameLength) * target.sampleRate / file.processingFormat.sampleRate) + 64
        let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity)!
        var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return input
        }
        if let error { throw error }
        return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
    }
}
