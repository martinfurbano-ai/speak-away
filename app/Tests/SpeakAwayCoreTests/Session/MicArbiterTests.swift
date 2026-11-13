import XCTest
@testable import SpeakAwayCore

/// One owner of the microphone: a keyboard dictation session or a meeting, never both.
final class MicArbiterTests: XCTestCase {
    func testAMeetingStartsWhenNobodyHasTheMic() {
        XCTAssertEqual(MicArbiter.decide(.meeting, owner: .nobody), .grant)
    }

    func testAMeetingEndsTheDictationSessionBeforeItStarts() {
        XCTAssertEqual(MicArbiter.decide(.meeting, owner: .dictation), .endDictationFirst)
    }

    func testASecondMeetingIsRefused() {
        XCTAssertEqual(MicArbiter.decide(.meeting, owner: .meeting), .refuse(.meetingAlreadyRecording))
    }

    func testADictationStartsWhenNobodyHasTheMic() {
        XCTAssertEqual(MicArbiter.decide(.dictation, owner: .nobody), .grant)
    }

    func testADictationOnItsOwnSessionIsGranted() {
        XCTAssertEqual(MicArbiter.decide(.dictation, owner: .dictation), .grant)
    }

    func testADictationCannotStartWhileAMeetingRecords() {
        XCTAssertEqual(MicArbiter.decide(.dictation, owner: .meeting), .refuse(.meetingInProgress))
    }

    func testTheMeetingOwnsTheMicEvenIfADictationSessionIsStillLive() {
        XCTAssertEqual(MicOwner.current(dictationSessionLive: true, meetingActive: true), .meeting)
    }

    func testALiveSessionOwnsTheMicWhenThereIsNoMeeting() {
        XCTAssertEqual(MicOwner.current(dictationSessionLive: true, meetingActive: false), .dictation)
    }

    func testNobodyOwnsTheMicWhenNothingIsRunning() {
        XCTAssertEqual(MicOwner.current(dictationSessionLive: false, meetingActive: false), .nobody)
    }

    func testAPausedMeetingStillOwnsTheMic() {
        // The caller says "active" for a paused meeting too: it is not over, and the dictation must wait.
        XCTAssertEqual(MicOwner.current(dictationSessionLive: false, meetingActive: true), .meeting)
    }
}
