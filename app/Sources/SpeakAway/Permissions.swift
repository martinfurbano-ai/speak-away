import AVFoundation
import AppKit
import ApplicationServices

/// The three permissions dictation needs, and where to grant each one.
enum Permission: CaseIterable {
    case microphone, fnKey, paste

    var title: String {
        switch self {
        case .microphone: return "Micrófono"
        case .fnKey: return "Tecla Fn"
        case .paste: return "Pegar el texto"
        }
    }

    var detail: String {
        switch self {
        case .microphone: return "Para escucharte mientras dictas."
        case .fnKey: return "Monitoreo de entrada: para notar cuando tocas Fn."
        case .paste: return "Accesibilidad: para pegar el texto donde está tu cursor."
        }
    }

    var granted: Bool {
        switch self {
        case .microphone: return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .fnKey: return CGPreflightListenEventAccess()
        case .paste: return AXIsProcessTrusted()
        }
    }

    func request() {
        switch self {
        case .microphone:
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            } else {
                openSettings("Privacy_Microphone")
            }
        case .fnKey:
            if !CGRequestListenEventAccess() { openSettings("Privacy_ListenEvent") }
        case .paste:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            if !AXIsProcessTrustedWithOptions(options) { openSettings("Privacy_Accessibility") }
        }
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    static var allGranted: Bool { allCases.allSatisfy(\.granted) }
}
