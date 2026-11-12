import AVFoundation

/// Turns speech into text. The session depends on this, not on Apple's framework, so the session
/// logic can be checked with a stand-in and the engine can change without touching the rest.
protocol Transcriber: AnyObject {
    /// The locale to listen in for a language setting ("auto", "es", "en-GB"): a supported one, else en-US.
    func resolveLocale(setting: String) async -> Locale

    /// Makes sure everything needed to listen in `locale` is on this phone, installing it when missing.
    /// `progress` reports 0...1 while a download runs, from any thread.
    func prepare(locale: Locale, progress: @escaping @Sendable (Double) -> Void) async throws

    /// Starts one dictation. Audio can be fed at once; it is held until the engine is ready.
    func startStream(locale: Locale) -> TranscriptionStream
}

protocol TranscriptionStream: AnyObject {
    /// Adds audio in any format. Called from the audio thread; the buffer is copied.
    func feed(_ buffer: AVAudioPCMBuffer)
    /// No more audio: finishes the analysis and returns the final text.
    func finish() async throws -> String
    /// Throws the dictation away.
    func cancel() async
}

enum TranscriberError: Error, Equatable {
    case unsupportedLocale(String)
    case assetsUnavailable(String)
    case noAudioFormat
    case conversionFailed
}
