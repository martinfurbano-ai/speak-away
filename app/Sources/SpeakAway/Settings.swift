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
