import Foundation

/// The five screens of the first launch, in order.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 1
    case permissions
    case speechModel
    case keyboard
    case tryIt
}

/// Where the speech model for the chosen language stands.
public enum SpeechModelState: Equatable, Sendable {
    case unknown
    case missing
    case downloading(Double)
    case installed
    case failed

    /// 0 to 1, for the progress bar.
    public var fraction: Double {
        switch self {
        case .installed: 1
        case .downloading(let p): min(1, max(0, p))
        case .unknown, .missing, .failed: 0
        }
    }
}

/// The rules that decide which screen comes next and what the buttons do.
public enum Onboarding {
    /// The screens that will be shown. The model screen is passed over when the model is already installed.
    public static func steps(modelInstalled: Bool) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { !(modelInstalled && $0 == .speechModel) }
    }

    public static func next(after step: OnboardingStep, modelInstalled: Bool) -> OnboardingStep? {
        steps(modelInstalled: modelInstalled).first { $0.rawValue > step.rawValue }
    }

    public static func previous(before step: OnboardingStep, modelInstalled: Bool) -> OnboardingStep? {
        steps(modelInstalled: modelInstalled).last { $0.rawValue < step.rawValue }
    }

    /// The main button moves on. The microphone and the speech model have to be ready first.
    public static func canContinue(from step: OnboardingStep, micAllowed: Bool, model: SpeechModelState) -> Bool {
        switch step {
        case .welcome, .keyboard, .tryIt: true
        case .permissions: micAllowed
        case .speechModel: model == .installed
        }
    }

    /// The quiet "later" button. The app can still ask for the microphone or fetch the model when it needs them.
    public static func canSkip(_ step: OnboardingStep, micAllowed: Bool, model: SpeechModelState) -> Bool {
        switch step {
        case .permissions: !micAllowed
        case .speechModel: model != .installed
        case .welcome, .keyboard, .tryIt: false
        }
    }

    /// "Step 3 of 4" counted over the screens that will be shown.
    public static func position(of step: OnboardingStep, modelInstalled: Bool) -> (index: Int, total: Int) {
        let shown = steps(modelInstalled: modelInstalled)
        let upTo = shown.filter { $0.rawValue <= step.rawValue }.count
        return (max(1, upTo), shown.count)
    }
}
