import Foundation
import SpeakAwayBrain
import SpeakAwayCore

/// What the on-device model can do, as closures, so the session can be checked without Apple Intelligence.
struct OnDeviceBrain {
    var availability: () -> BrainAvailability
    /// Light rewrite of a dictation. Returns the text unchanged on any failure.
    var polish: (_ text: String, _ style: String, _ language: String?) async -> String
    /// Applies a spoken instruction to a text (Command Mode).
    var command: (_ instruction: String, _ text: String, _ language: String?) async throws -> String

    static let live = OnDeviceBrain(
        availability: { LocalBrain.availability },
        polish: { text, style, language in (try? await LocalBrain.polish(text, style: style, language: language)) ?? text },
        command: { instruction, text, language in try await LocalBrain.command(instruction, on: text, language: language) })
}
