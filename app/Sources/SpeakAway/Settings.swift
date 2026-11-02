import Foundation

enum Settings {
    static let models: [(id: String, label: String)] = [
        ("openai_whisper-large-v3-v20240930_turbo_632MB", "Preciso (632 MB)"),
        ("openai_whisper-small_216MB", "Rápido (216 MB)"),
    ]
    static let languages: [(id: String, label: String)] = [
        ("auto", "Automático"),
        ("es", "Español"),
        ("en", "English"),
    ]

    private static let store = UserDefaults.standard

    static var model: String {
        get { store.string(forKey: "model") ?? models[0].id }
        set { store.set(newValue, forKey: "model") }
    }

    static var language: String {
        get { store.string(forKey: "language") ?? "auto" }
        set { store.set(newValue, forKey: "language") }
    }

    /// Device UID of the chosen mic; empty means the system default.
    static var microphone: String {
        get { store.string(forKey: "microphone") ?? "" }
        set { store.set(newValue, forKey: "microphone") }
    }

    static var sounds: Bool {
        get { store.object(forKey: "sounds") as? Bool ?? true }
        set { store.set(newValue, forKey: "sounds") }
    }

    /// Remove filler words and apply spoken corrections ("a las 2, no, a las 3").
    static var autoEdit: Bool {
        get { store.object(forKey: "autoEdit") as? Bool ?? true }
        set { store.set(newValue, forKey: "autoEdit") }
    }

    /// Light rewrite with Apple's on-device model after dictating (Wispr Flow's Polish). Off by default: slower.
    static var polish: Bool {
        get { store.bool(forKey: "polish") }
        set { store.set(newValue, forKey: "polish") }
    }

    static var welcomed: Bool {
        get { store.bool(forKey: "welcomed") }
        set { store.set(newValue, forKey: "welcomed") }
    }

    static var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Speak Away/Models", isDirectory: true)
    }

    static let website = URL(string: "https://speakaway.heliospanama.com")!
    static let instagram = URL(string: "https://www.instagram.com/opensourceeverything/")!
    static let github = URL(string: "https://github.com/martinfurbano-ai/speak-away")!
}
