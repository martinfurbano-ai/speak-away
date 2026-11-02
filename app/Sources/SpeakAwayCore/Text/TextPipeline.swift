import Foundation

/// Everything that happens to a transcript after SpeechGate.clean and before it is typed.
public enum TextPipeline {
    /// Order: personal dictionary, auto-edits (when on), snippets, writing style.
    /// A dictation that is only a snippet is inserted exactly as the snippet says, without the style.
    /// Leading and trailing whitespace (the space SpeechGate adds) is kept.
    public static func process(
        raw: String,
        language: String?,
        dictionary: PersonalDictionary,
        snippets: Snippets,
        style: WritingStyle,
        autoEdit: Bool
    ) -> String {
        let (lead, core, trail) = TextEnvelope.split(raw)
        if core.isEmpty { return raw }
        let corrected = dictionary.apply(to: core)
        let edited = autoEdit ? AutoEdit.clean(corrected, language: language) : corrected
        let expanded = snippets.expandWithInfo(edited)
        let finished = expanded.replacedWholeUtterance ? expanded.text : Style.apply(expanded.text, style: style)
        return lead + finished + trail
    }
}
