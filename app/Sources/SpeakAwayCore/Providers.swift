import Foundation

/// Which engine does each job. Mirrors speakaway/providers.py: Speak Away never needs a key.
public enum Providers {
    public struct Choice: Equatable, Sendable {
        public let stt: String
        public let brain: String
        public init(stt: String, brain: String) { self.stt = stt; self.brain = brain }
    }

    public static let cloudSTT = ["openai", "groq", "elevenlabs", "deepgram"]
    public static let keylessBrains = ["none", "ollama", "mcp"]
    public static let cloudBrains = ["anthropic", "openai", "groq", "openrouter"] // order used by "auto"

    public static func resolve(stt: String, brain: String, keys: Set<String>) -> Choice {
        let chosenSTT = cloudSTT.contains(stt) && keys.contains(stt) ? stt : "local"
        let chosenBrain: String
        if keylessBrains.contains(brain) {
            chosenBrain = brain
        } else if cloudBrains.contains(brain) && keys.contains(brain) {
            chosenBrain = brain
        } else if brain == "auto" {
            chosenBrain = cloudBrains.first(where: keys.contains) ?? "none"
        } else {
            chosenBrain = "none"
        }
        return Choice(stt: chosenSTT, brain: chosenBrain)
    }
}
