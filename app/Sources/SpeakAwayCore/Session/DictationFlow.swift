import Foundation

/// A dictation after the text rules, ready to insert.
public struct PreparedDictation: Equatable, Sendable {
    /// What the speech engine heard, cleaned of noise (with the trailing space).
    public let raw: String
    /// What the keyboard inserts.
    public let text: String
    /// The style that was applied.
    public let style: WritingStyle
}

/// The text path of a dictation, the same as on the Mac: SpeechGate clean, then the personal
/// dictionary, auto-edits, snippets and the writing style. The on-device brain (optional) runs after this.
public enum DictationFlow {
    /// `nil` when the engine heard only noise or nothing.
    public static func prepare(transcript: String, language: String?, field: FieldContext, dictionary: PersonalDictionary,
                               snippets: Snippets, styles: StyleSettings, autoEdit: Bool) -> PreparedDictation? {
        let raw = SpeechGate.clean(transcript)
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let style = field.style(in: styles)
        let text = TextPipeline.process(raw: raw, language: language, dictionary: dictionary, snippets: snippets,
                                        style: style, autoEdit: autoEdit)
        return PreparedDictation(raw: raw, text: text, style: style)
    }
}
