import Foundation
import SpeakAwayCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The brain: cleanup, Command Mode and meeting summaries, all on this device with Apple's
/// on-device model. Shared by the Mac and iPhone apps. No API key, no network. When it is not
/// available every call says so (or, for `polish`, leaves the text as it was).
public enum LocalBrain {
    // MARK: Availability

    public static var availability: BrainAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .appleIntelligenceNotEnabled: return .needsAppleIntelligence
                case .deviceNotEligible: return .deviceNotEligible
                case .modelNotReady: return .modelNotReady
                @unknown default: return .unsupportedOS
                }
            }
        }
        #endif
        return .unsupportedOS
    }

    // MARK: Polish

    /// Light cleanup of a dictation. Returns the original text on any failure.
    public static func polish(_ text: String, style: String, language: String?) async throws -> String {
        guard availability.isUsable, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            do {
                let limit = BrainLimits.maxCommandChars(contextTokens: SystemLanguageModel.default.contextSize)
                let pieces = TextChunker.chunks(text, maxChars: limit)
                var out: [String] = []
                for piece in pieces {
                    let p = BrainPrompts.polish(text: piece, style: style, language: language)
                    let answer = try await run(p, temperature: 0.2)
                    out.append(BrainGuard.acceptPolish(original: piece, candidate: answer))
                }
                return pieces.count == 1 ? out[0] : out.joined(separator: " ")
            } catch {
                return text
            }
        }
        #endif
        return text
    }

    // MARK: Command Mode

    /// "hazlo más formal", "tradúcelo al inglés", "resúmelo en 3 bullets", applied to `selected`.
    public static func command(_ instruction: String, on selected: String, language: String?) async throws -> String {
        let status = availability
        guard status.isUsable else { throw BrainError.unavailable(status) }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let limit = BrainLimits.maxCommandChars(contextTokens: SystemLanguageModel.default.contextSize)
            guard selected.count <= limit else { throw BrainError.tooLong }
            let p = BrainPrompts.command(instruction: instruction, selected: selected, language: language)
            do {
                let answer = try await run(p, temperature: 0.3)
                guard let result = BrainGuard.acceptCommand(answer) else {
                    throw BrainError.failed("El modelo no devolvió texto. Prueba con otra instrucción.")
                }
                return result
            } catch let error as BrainError {
                throw error
            } catch {
                throw map(error)
            }
        }
        #endif
        throw BrainError.unavailable(.unsupportedOS)
    }

    // MARK: Meeting summary

    /// Summarizes a transcript of any length: chunks that fit the context window are summarized
    /// one by one and then merged.
    public static func summarize(transcript: String, language: String?) async throws -> MeetingSummary {
        let status = availability
        guard status.isUsable else { throw BrainError.unavailable(status) }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            var limit = BrainLimits.maxChunkChars(contextTokens: SystemLanguageModel.default.contextSize)
            // If a chunk still overflows the window, halve the chunk size and start over.
            for attempt in 0..<3 {
                let chunks = TextChunker.chunks(transcript, maxChars: limit)
                guard !chunks.isEmpty else { return MeetingSummary(summary: "", decisions: [], actionItems: [], questions: []) }
                do {
                    var notes: [MeetingSummary] = []
                    for (i, chunk) in chunks.enumerated() {
                        notes.append(try await summarizeChunk(chunk, language: language, part: i + 1, of: chunks.count))
                    }
                    if notes.count == 1 { return notes[0].cleaned() }
                    let overall = try await mergeSummaryTexts(notes.map(\.summary), language: language, limit: limit)
                    return MeetingSummary.merging(notes, summary: overall)
                } catch let error as LanguageModelSession.GenerationError {
                    if case .exceededContextWindowSize = error, attempt < 2 {
                        limit /= 2
                        continue
                    }
                    throw map(error)
                }
            }
            throw BrainError.tooLong
        }
        #endif
        throw BrainError.unavailable(.unsupportedOS)
    }

    #if canImport(FoundationModels)
    // MARK: Foundation Models plumbing

    @available(macOS 26.0, iOS 26.0, *)
    @Generable
    struct GeneratedNotes {
        @Guide(description: "A short summary of what was discussed, one or two paragraphs.")
        var summary: String
        @Guide(description: "Decisions that were made. Empty if there were none.")
        var decisions: [String]
        @Guide(description: "Tasks someone has to do, with the owner when the transcript names one. Empty if there were none.")
        var actionItems: [String]
        @Guide(description: "Questions left open. Empty if there were none.")
        var questions: [String]
    }

    /// A fresh session per call: the brain keeps no conversation between requests.
    @available(macOS 26.0, iOS 26.0, *)
    private static func run(_ p: BrainPrompt, temperature: Double) async throws -> String {
        let session = LanguageModelSession(instructions: p.instructions)
        let response = try await session.respond(to: p.prompt, options: GenerationOptions(temperature: temperature))
        return response.content
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func summarizeChunk(_ chunk: String, language: String?, part: Int, of total: Int) async throws -> MeetingSummary {
        let p = BrainPrompts.chunkSummary(transcript: chunk, language: language, part: part, of: total)
        let session = LanguageModelSession(instructions: p.instructions)
        let response = try await session.respond(
            to: p.prompt, generating: GeneratedNotes.self, options: GenerationOptions(temperature: 0.2))
        let g = response.content
        return MeetingSummary(summary: g.summary, decisions: g.decisions, actionItems: g.actionItems, questions: g.questions).cleaned()
    }

    /// Condenses partial summaries into one text, in rounds when even the summaries do not fit one call.
    @available(macOS 26.0, iOS 26.0, *)
    private static func mergeSummaryTexts(_ texts: [String], language: String?, limit: Int) async throws -> String {
        var current = texts.map { String($0.prefix(limit)) }.filter { !$0.isEmpty }
        for _ in 0..<4 {
            let groups = TextChunker.groups(current, maxChars: limit)
            if groups.count <= 1 {
                guard let only = groups.first else { return "" }
                if only.count == 1 { return only[0] }
                return try await run(BrainPrompts.mergeSummaries(only, language: language), temperature: 0.2)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            var next: [String] = []
            for group in groups {
                if group.count == 1 { next.append(group[0]); continue }
                next.append(try await run(BrainPrompts.mergeSummaries(group, language: language), temperature: 0.2)
                    .trimmingCharacters(in: .whitespacesAndNewlines))
            }
            current = next
        }
        return current.joined(separator: "\n\n")
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func map(_ error: Error) -> BrainError {
        guard let generation = error as? LanguageModelSession.GenerationError else {
            return .failed(error.localizedDescription)
        }
        switch generation {
        case .exceededContextWindowSize: return .tooLong
        case .guardrailViolation, .refusal: return .failed("Apple Intelligence no pudo procesar ese texto.")
        case .unsupportedLanguageOrLocale: return .failed("Apple Intelligence todavía no admite ese idioma.")
        case .assetsUnavailable: return .unavailable(.modelNotReady)
        case .rateLimited, .concurrentRequests: return .failed("El modelo está ocupado. Inténtalo de nuevo en un momento.")
        default: return .failed(generation.localizedDescription)
        }
    }
    #endif
}
