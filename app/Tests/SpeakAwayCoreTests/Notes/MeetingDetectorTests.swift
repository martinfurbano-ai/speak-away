import XCTest
@testable import SpeakAwayCore

final class MeetingDetectorTests: XCTestCase {
    func testNothingRunning() {
        XCTAssertNil(MeetingDetector.detect(running: [], micUsers: [], micInUse: false))
    }

    func testMeetingAppUsingTheMic() {
        let app = MeetingDetector.detect(running: ["us.zoom.xos", "com.apple.finder"], micUsers: ["us.zoom.xos"], micInUse: true)
        XCTAssertEqual(app?.name, "Zoom")
        XCTAssertEqual(app?.bundleID, "us.zoom.xos")
    }

    func testBothZoomBundleIDs() {
        XCTAssertEqual(MeetingDetector.detect(running: ["zoom.us"], micUsers: ["zoom.us"], micInUse: true)?.name, "Zoom")
    }

    func testKnownApps() {
        let cases: [(String, String)] = [
            ("com.microsoft.teams2", "Microsoft Teams"),
            ("com.microsoft.teams", "Microsoft Teams"),
            ("com.apple.FaceTime", "FaceTime"),
            ("com.cisco.webexmeetings", "Webex"),
            ("com.tinyspeck.slackmacgap", "Slack"),
        ]
        for (id, name) in cases {
            XCTAssertEqual(MeetingDetector.detect(running: [id], micUsers: [id], micInUse: true)?.name, name, id)
        }
    }

    func testMeetingAppRunningButMicIdleIsNotAMeeting() {
        XCTAssertNil(MeetingDetector.detect(running: ["us.zoom.xos"], micUsers: [], micInUse: false))
    }

    func testFallbackWithoutAttributionUsesOnlyDedicatedApps() {
        // macOS cannot tell who holds the mic: a dedicated meeting app that is running is the best guess.
        XCTAssertEqual(MeetingDetector.detect(running: ["us.zoom.xos"], micUsers: [], micInUse: true)?.name, "Zoom")
    }

    func testFallbackNeverGuessesSlackOrBrowsers() {
        XCTAssertNil(MeetingDetector.detect(running: ["com.tinyspeck.slackmacgap", "com.google.Chrome"], micUsers: [], micInUse: true))
    }

    func testAttributionWinsOverRunningApps() {
        // Zoom is open in the background but the mic belongs to a dictation tool.
        XCTAssertNil(MeetingDetector.detect(running: ["us.zoom.xos"], micUsers: ["com.example.dictation"], micInUse: true))
    }

    func testBrowserOnlyCountsWhenWeCanTellItIsMeet() {
        XCTAssertNil(MeetingDetector.detect(running: ["com.google.Chrome"], micUsers: ["com.google.Chrome"], micInUse: true))
        let app = MeetingDetector.detect(running: ["com.google.Chrome"], micUsers: ["com.google.Chrome"], micInUse: true, meetBrowsers: ["com.google.Chrome"])
        XCTAssertEqual(app?.name, "Google Meet")
    }

    func testPriorityIsDeterministic() {
        let users: Set<String> = ["com.tinyspeck.slackmacgap", "us.zoom.xos"]
        for _ in 0..<20 {
            XCTAssertEqual(MeetingDetector.detect(running: users, micUsers: users, micInUse: true)?.name, "Zoom")
        }
    }

    func testIgnoresOwnBundle() {
        XCTAssertNil(MeetingDetector.detect(running: ["com.opensourceeverything.speakaway"], micUsers: ["com.opensourceeverything.speakaway"], micInUse: true))
    }
}

final class MeetingPresenceTests: XCTestCase {
    let zoom = MeetingApp(bundleID: "us.zoom.xos", name: "Zoom")

    func feed(_ presence: MeetingPresence, _ observations: [MeetingApp?]) -> (MeetingPresence, [MeetingPresence.Event]) {
        observations.reduce((presence, [])) { acc, obs in
            let (next, event) = acc.0.observing(obs)
            return (next, acc.1 + (event.map { [$0] } ?? []))
        }
    }

    func testStartsAfterTwoConsecutiveSightings() {
        let (_, events) = feed(MeetingPresence(), [zoom, zoom])
        XCTAssertEqual(events, [.started(zoom)])
    }

    func testOneSightingIsNotEnough() {
        let (_, events) = feed(MeetingPresence(), [zoom, nil, zoom, nil])
        XCTAssertEqual(events, [])
    }

    func testStartedFiresOnlyOncePerMeeting() {
        let (_, events) = feed(MeetingPresence(), [zoom, zoom, zoom, zoom, zoom])
        XCTAssertEqual(events, [.started(zoom)])
    }

    func testEndsAfterThreeMisses() {
        let (_, events) = feed(MeetingPresence(), [zoom, zoom, nil, nil, nil])
        XCTAssertEqual(events, [.started(zoom), .ended])
    }

    func testShortGapDoesNotEndTheMeeting() {
        let (_, events) = feed(MeetingPresence(), [zoom, zoom, nil, nil, zoom, nil, nil, zoom])
        XCTAssertEqual(events, [.started(zoom)])
    }

    func testSecondMeetingAfterTheFirstEnded() {
        let (_, events) = feed(MeetingPresence(), [zoom, zoom, nil, nil, nil, zoom, zoom])
        XCTAssertEqual(events, [.started(zoom), .ended, .started(zoom)])
    }

    func testObservingReturnsNewValue() {
        let p = MeetingPresence()
        _ = p.observing(zoom)
        XCTAssertEqual(p, MeetingPresence())
    }
}
