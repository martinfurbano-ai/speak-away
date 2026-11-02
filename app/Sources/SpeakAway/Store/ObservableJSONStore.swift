import Foundation
import SpeakAwayCore

/// A Codable value kept in one JSON file and published to the interface.
/// The dictionary, snippets and style stores are this store with their own value type:
/// `ObservableJSONStore<PersonalDictionary>(file: StorePaths.file(StorePaths.dictionary), default: ...)`.
@MainActor
final class ObservableJSONStore<Value: Codable>: ObservableObject {
    @Published private(set) var value: Value
    private let file: JSONFileStore<Value>

    init(file url: URL, default defaultValue: @autoclosure () -> Value) {
        file = JSONFileStore(url: url)
        value = file.load(default: defaultValue())
    }

    /// Replaces the value with the result of `transform` and saves it. The old value is not mutated.
    func update(_ transform: (Value) -> Value) {
        value = transform(value)
        try? file.save(value)
    }
}
