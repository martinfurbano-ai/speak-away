import XCTest
@testable import SpeakAwayCore

final class PreviewRequestTests: XCTestCase {
    func testTheScreenNamesAreTheOnesTheScreenshotScriptUses() {
        XCTAssertEqual(PreviewScreen.allCases.map(\.rawValue), [
            "home", "history", "notes", "meetings", "meeting-detail", "meeting-recording", "voice", "dictionary", "snippets", "style", "settings",
            "onboarding-1", "onboarding-2", "onboarding-3", "onboarding-4", "onboarding-5",
            "session", "keyboard", "keyboard-recording", "keyboard-result",
        ])
    }

    func testReadsTheScreenAfterThePreviewFlag() {
        let request = PreviewRequest(arguments: ["SpeakAway", "--preview", "meeting-detail"])
        XCTAssertEqual(request?.screen, .meetingDetail)
        XCTAssertNil(request?.appearance)
    }

    func testReadsTheAppearanceWhenGiven() {
        XCTAssertEqual(PreviewRequest(arguments: ["--preview", "home", "--appearance", "dark"])?.appearance, .dark)
        XCTAssertEqual(PreviewRequest(arguments: ["--appearance", "light", "--preview", "home"])?.appearance, .light)
    }

    func testAnUnknownAppearanceFollowsTheSystem() {
        let request = PreviewRequest(arguments: ["--preview", "home", "--appearance", "sepia"])
        XCTAssertEqual(request?.screen, .home)
        XCTAssertNil(request?.appearance)
    }

    func testWithoutAValidScreenThereIsNoPreview() {
        XCTAssertNil(PreviewRequest(arguments: ["SpeakAway"]))
        XCTAssertNil(PreviewRequest(arguments: ["--preview"]))
        XCTAssertNil(PreviewRequest(arguments: ["--preview", "nowhere"]))
        XCTAssertNil(PreviewRequest(arguments: ["--appearance", "dark"]))
    }

    func testTheScreenNameIsMatchedWithoutCase() {
        XCTAssertEqual(PreviewRequest(arguments: ["--preview", "Keyboard-Result"])?.screen, .keyboardResult)
    }

    func testOnboardingScreensKnowTheirStep() {
        XCTAssertEqual(PreviewScreen.onboarding1.onboardingStep, .welcome)
        XCTAssertEqual(PreviewScreen.onboarding3.onboardingStep, .speechModel)
        XCTAssertEqual(PreviewScreen.onboarding5.onboardingStep, .tryIt)
        XCTAssertNil(PreviewScreen.home.onboardingStep)
    }
}
