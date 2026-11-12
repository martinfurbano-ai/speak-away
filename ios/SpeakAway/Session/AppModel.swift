import SwiftUI
import SpeakAwayCore

/// Which screen the app shows and what opens it. The keyboard opens the app with `speakaway://session/start`
/// to begin a session and with `speakaway://setup` when it needs Full Access.
@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case home
        case listening
        case setup
    }

    @Published var screen: Screen = .home
    let session: SessionController

    init(session: SessionController? = nil) {
        self.session = session ?? SessionController()
    }

    func open(_ url: URL) {
        guard url.scheme?.lowercased() == SessionChannel.urlScheme else { return }
        switch url.host?.lowercased() {
        case "session":
            screen = .listening
            Task { await session.startSession() }
        case "setup":
            screen = .setup
        default:
            break
        }
    }
}
