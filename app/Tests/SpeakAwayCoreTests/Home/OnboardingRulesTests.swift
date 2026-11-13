import XCTest
@testable import SpeakAwayCore

final class OnboardingRulesTests: XCTestCase {
    func testTheFiveSteps() {
        XCTAssertEqual(OnboardingStep.allCases.map(\.rawValue), [1, 2, 3, 4, 5])
        XCTAssertEqual(OnboardingStep(rawValue: 3), .speechModel)
        XCTAssertNil(OnboardingStep(rawValue: 6))
    }

    func testNextWalksThroughTheStepsInOrder() {
        var step: OnboardingStep? = .welcome
        var seen: [OnboardingStep] = []
        while let current = step {
            seen.append(current)
            step = Onboarding.next(after: current, modelInstalled: false)
        }
        XCTAssertEqual(seen, [.welcome, .permissions, .speechModel, .keyboard, .tryIt])
    }

    func testTheModelStepIsPassedOverWhenTheModelIsInstalled() {
        XCTAssertEqual(Onboarding.next(after: .permissions, modelInstalled: true), .keyboard)
        XCTAssertEqual(Onboarding.previous(before: .keyboard, modelInstalled: true), .permissions)
        XCTAssertEqual(Onboarding.next(after: .permissions, modelInstalled: false), .speechModel)
        XCTAssertEqual(Onboarding.previous(before: .keyboard, modelInstalled: false), .speechModel)
    }

    func testThereIsNothingBeforeTheFirstOrAfterTheLastStep() {
        XCTAssertNil(Onboarding.previous(before: .welcome, modelInstalled: false))
        XCTAssertNil(Onboarding.next(after: .tryIt, modelInstalled: true))
    }

    func testWelcomeKeyboardAndTryItAlwaysContinue() {
        for step in [OnboardingStep.welcome, .keyboard, .tryIt] {
            XCTAssertTrue(Onboarding.canContinue(from: step, micAllowed: false, model: .missing), "\(step)")
        }
    }

    func testPermissionsNeedTheMicrophone() {
        XCTAssertFalse(Onboarding.canContinue(from: .permissions, micAllowed: false, model: .unknown))
        XCTAssertTrue(Onboarding.canContinue(from: .permissions, micAllowed: true, model: .unknown))
    }

    func testTheModelStepContinuesOnlyOnceTheModelIsInstalled() {
        XCTAssertFalse(Onboarding.canContinue(from: .speechModel, micAllowed: true, model: .missing))
        XCTAssertFalse(Onboarding.canContinue(from: .speechModel, micAllowed: true, model: .downloading(0.4)))
        XCTAssertFalse(Onboarding.canContinue(from: .speechModel, micAllowed: true, model: .failed))
        XCTAssertTrue(Onboarding.canContinue(from: .speechModel, micAllowed: true, model: .installed))
    }

    func testSkipping() {
        XCTAssertTrue(Onboarding.canSkip(.permissions, micAllowed: false, model: .missing))
        XCTAssertFalse(Onboarding.canSkip(.permissions, micAllowed: true, model: .missing))
        XCTAssertTrue(Onboarding.canSkip(.speechModel, micAllowed: true, model: .downloading(0.1)))
        XCTAssertTrue(Onboarding.canSkip(.speechModel, micAllowed: true, model: .failed))
        XCTAssertFalse(Onboarding.canSkip(.speechModel, micAllowed: true, model: .installed), "it is passed over instead")
        XCTAssertFalse(Onboarding.canSkip(.welcome, micAllowed: false, model: .missing))
        XCTAssertFalse(Onboarding.canSkip(.keyboard, micAllowed: false, model: .missing))
    }

    func testPositionCountsOnlyTheStepsThatWillBeShown() {
        XCTAssertEqual(Onboarding.position(of: .keyboard, modelInstalled: false).index, 4)
        XCTAssertEqual(Onboarding.position(of: .keyboard, modelInstalled: false).total, 5)
        XCTAssertEqual(Onboarding.position(of: .keyboard, modelInstalled: true).index, 3)
        XCTAssertEqual(Onboarding.position(of: .keyboard, modelInstalled: true).total, 4)
        XCTAssertEqual(Onboarding.position(of: .welcome, modelInstalled: true).index, 1)
    }

    func testTheProgressFractionOfTheModelStateIsClamped() {
        XCTAssertEqual(SpeechModelState.downloading(0.25).fraction, 0.25)
        XCTAssertEqual(SpeechModelState.downloading(1.7).fraction, 1)
        XCTAssertEqual(SpeechModelState.downloading(-1).fraction, 0)
        XCTAssertEqual(SpeechModelState.installed.fraction, 1)
        XCTAssertEqual(SpeechModelState.missing.fraction, 0)
    }
}
