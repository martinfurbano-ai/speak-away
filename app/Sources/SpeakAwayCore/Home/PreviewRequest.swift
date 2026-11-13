import Foundation

/// The screens the iPhone app can show with fictional sample data (`--preview <name>`), for screenshots.
public enum PreviewScreen: String, CaseIterable, Sendable {
    case home
    case history
    case notes
    case meetings
    case meetingDetail = "meeting-detail"
    case voice
    case dictionary
    case snippets
    case style
    case settings
    case onboarding1 = "onboarding-1"
    case onboarding2 = "onboarding-2"
    case onboarding3 = "onboarding-3"
    case onboarding4 = "onboarding-4"
    case onboarding5 = "onboarding-5"
    case session
    case keyboard
    case keyboardRecording = "keyboard-recording"
    case keyboardResult = "keyboard-result"

    /// The first-launch step this screen shows, if it is one of the onboarding screens.
    public var onboardingStep: OnboardingStep? {
        switch self {
        case .onboarding1: .welcome
        case .onboarding2: .permissions
        case .onboarding3: .speechModel
        case .onboarding4: .keyboard
        case .onboarding5: .tryIt
        default: nil
        }
    }
}

public enum PreviewAppearance: String, Sendable {
    case light, dark
}

/// `--preview <screen> [--appearance light|dark]` from the launch arguments.
public struct PreviewRequest: Equatable, Sendable {
    public let screen: PreviewScreen
    /// `nil`: follow the system.
    public let appearance: PreviewAppearance?

    public init(screen: PreviewScreen, appearance: PreviewAppearance? = nil) {
        self.screen = screen
        self.appearance = appearance
    }

    /// `nil` when the arguments do not ask for a known screen, so a normal launch never previews by accident.
    public init?(arguments: [String]) {
        guard let screen = Self.value(after: "--preview", in: arguments).flatMap({ PreviewScreen(rawValue: $0.lowercased()) }) else {
            return nil
        }
        self.screen = screen
        self.appearance = Self.value(after: "--appearance", in: arguments).flatMap { PreviewAppearance(rawValue: $0.lowercased()) }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
