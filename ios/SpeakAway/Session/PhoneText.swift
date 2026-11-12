import Foundation
import SpeakAwayCore

/// The words the phone shows when something goes wrong, in plain English. One place, so the app and the
/// keyboard say the same thing.
enum PhoneText {
    static func reason(for error: Error) -> String {
        switch error {
        case let error as AudioInputError:
            switch error {
            case .microphoneDenied: return "Microphone access is off. Allow it in Settings to dictate."
            case .noMicrophone: return "No microphone is available right now."
            case .cannotStart: return "The microphone could not start. Close other apps that are using it and try again."
            }
        case let error as TranscriberError:
            switch error {
            case .unsupportedLocale(let id): return "Speech recognition is not available for \(id) on this iPhone."
            case .assetsUnavailable: return "Could not get the speech model. Check your connection and try again."
            case .noAudioFormat, .conversionFailed: return "The audio could not be read. Try again."
            }
        case let error as BrainError:
            switch error {
            case .unavailable(let status): return brain(status)
            case .tooLong: return "That text is too long for Command Mode."
            case .failed: return "The model did not return any text. Try another instruction."
            }
        case is CancellationError:
            return "Stopped."
        default:
            return "Something went wrong. Try again."
        }
    }

    static func brain(_ status: BrainAvailability) -> String {
        switch status {
        case .available: return ""
        case .needsAppleIntelligence: return "Turn on Apple Intelligence in Settings to use Command Mode."
        case .unsupportedOS, .deviceNotEligible: return "Command Mode needs an iPhone that supports Apple Intelligence."
        case .modelNotReady: return "Apple Intelligence is still getting its model ready. Try again in a few minutes."
        }
    }
}
