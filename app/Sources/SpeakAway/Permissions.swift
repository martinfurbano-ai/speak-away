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
        // The preflight calls cache their first answer until the app restarts, so a permission granted
        // while Speak Away runs would still read as missing. Asking for a real event tap is always current.
        case .fnKey: return CGPreflightListenEventAccess() || Self.canListen()
        case .paste: return CGPreflightPostEventAccess() || AXIsProcessTrusted()
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
            // Works inside the App Store sandbox too: macOS lists the app under Accessibility.
            if !CGRequestPostEventAccess() { openSettings("Privacy_Accessibility") }
        }
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    static var allGranted: Bool { allCases.allSatisfy(\.granted) }

    /// True if macOS lets us listen to the keyboard right now (Input Monitoring).
    static func canListen() -> Bool {
        guard let probe = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
                                            callback: { _, _, event, _ in Unmanaged.passUnretained(event) }, userInfo: nil)
        else { return false }
        CFMachPortInvalidate(probe)
        return true
    }

    /// Some macOS versions only apply a new permission after a restart: reopen Speak Away cleanly.
    @MainActor static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
