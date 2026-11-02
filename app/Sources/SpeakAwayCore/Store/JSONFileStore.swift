import Foundation

/// Loads and saves one Codable value as a JSON file. Plain files, no database.
public struct JSONFileStore<Value: Codable> {
    public let url: URL

    public init(url: URL) { self.url = url }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// The saved value, or `defaultValue` when there is no file. A file that cannot be read is
    /// moved aside to `<name>.bak` instead of being overwritten later, and the default is returned.
    public func load(default defaultValue: @autoclosure () -> Value) -> Value {
        guard let data = try? Data(contentsOf: url) else { return defaultValue() }
        if let value = try? decoder.decode(Value.self, from: data) { return value }
        let backup = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url, to: backup)
        return defaultValue()
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    public func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
