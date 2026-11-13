import AVFoundation
import Speech
import UIKit

/// Opens this app's page in the Settings app.
enum SettingsLink {
    static func open() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

enum MicPermission {
    static var isAllowed: Bool { AVAudioApplication.shared.recordPermission == .granted }
    static var isDenied: Bool { AVAudioApplication.shared.recordPermission == .denied }

    /// Asks once; after a refusal only the Settings app can change the answer.
    static func request() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}

enum SpeechPermission {
    static var isAllowed: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }
    static var isDenied: Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        return status == .denied || status == .restricted
    }

    static func request() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
