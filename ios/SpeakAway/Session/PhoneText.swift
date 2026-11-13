import Foundation
import SpeakAwayCore

/// The words the phone shows when something goes wrong, in the language of the phone. One place, so the app and
/// the keyboard say the same thing. These texts are also written to the shared state file for the keyboard.
enum PhoneText {
    static func reason(for error: Error) -> String {
        switch error {
        case let error as AudioInputError:
            switch error {
            case .microphoneDenied: return String(localized: "Microphone access is off. Allow it in Settings to dictate.")
            case .noMicrophone: return String(localized: "No microphone is available right now.")
            case .cannotStart: return String(localized: "The microphone could not start. Close other apps that are using it and try again.")
            }
        case let error as TranscriberError:
            switch error {
            case .unsupportedLocale(let id): return String(localized: "Speech recognition is not available for \(id) on this iPhone.")
            case .assetsUnavailable: return String(localized: "Could not get the speech model. Check your connection and try again.")
            case .noAudioFormat, .conversionFailed: return String(localized: "The audio could not be read. Try again.")
            }
        case let error as BrainError:
            switch error {
            case .unavailable(let status): return brain(status)
            case .tooLong: return String(localized: "That text is too long for Command Mode.")
            case .failed: return String(localized: "The model did not return any text. Try another instruction.")
            }
        case is CancellationError:
            return String(localized: "Stopped.")
        default:
            return String(localized: "Something went wrong. Try again.")
        }
    }

    /// The only problem that is fixed in the Settings app: the microphone was turned off for Speak Away.
    static func needsSettings(_ error: Error) -> Bool {
        (error as? AudioInputError) == .microphoneDenied
    }

    static func brain(_ status: BrainAvailability) -> String {
        switch status {
        case .available: return ""
        case .needsAppleIntelligence: return String(localized: "Turn on Apple Intelligence in Settings to use Command Mode.")
        case .unsupportedOS, .deviceNotEligible: return String(localized: "Command Mode needs an iPhone that supports Apple Intelligence.")
        case .modelNotReady: return String(localized: "Apple Intelligence is still getting its model ready. Try again in a few minutes.")
        }
    }

    /// What the Brain row in Settings says about the on-device model, worded for the iPhone.
    static func brainSettingsDetail(_ status: BrainAvailability) -> String {
        switch status {
        case .available:
            return String(localized: "Uses Apple Intelligence on your iPhone. No keys, no accounts, nothing leaves your phone.")
        case .needsAppleIntelligence:
            return String(localized: "Turn on Apple Intelligence in the Settings app to use this.")
        case .unsupportedOS:
            return String(localized: "This needs iOS 26 or later with Apple Intelligence.")
        case .deviceNotEligible:
            return String(localized: "This iPhone does not support Apple Intelligence.")
        case .modelNotReady:
            return String(localized: "Apple Intelligence is still getting its model ready. Try again in a few minutes.")
        }
    }

    /// The length of a session, in the language of the phone (the Core titles are English only).
    static func title(for length: SessionLength) -> String {
        switch length {
        case .fiveMinutes: return String(localized: "5 minutes")
        case .fifteenMinutes: return String(localized: "15 minutes")
        case .oneHour: return String(localized: "1 hour")
        case .untilStopped: return String(localized: "Until I stop it")
        }
    }
}
