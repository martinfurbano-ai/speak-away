import XCTest
@testable import SpeakAwayCore

final class SessionFilesTests: XCTestCase {
    private var folder: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("session-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: State (app to keyboard)

    func testNoStateFileReadsAsNil() {
        XCTAssertNil(SessionFiles(folder: folder).readState())
    }

    func testStateWrittenByTheAppIsReadByTheKeyboard() {
        let app = SessionFiles(folder: folder)
        let keyboard = SessionFiles(folder: folder)
        let id = UUID()
        app.write(state: .done(id: id, text: "hello "), at: now, command: true)
        let record = keyboard.readState()
        XCTAssertEqual(record?.state, .done(id: id, text: "hello "))
        XCTAssertEqual(record?.updatedAt, now)
        XCTAssertEqual(record?.command, true)
    }

    func testTheLatestStateReplacesThePreviousOne() {
        let files = SessionFiles(folder: folder)
        files.write(state: .ready(until: nil), at: now)
        files.write(state: .recording(level: 0.5), at: now.addingTimeInterval(1))
        XCTAssertEqual(files.readState()?.state, .recording(level: 0.5))
    }

    func testAnUnreadableStateFileIsLeftAloneAndReadsAsNil() throws {
        let files = SessionFiles(folder: folder)
        let url = folder.appendingPathComponent(SessionChannel.stateFile)
        try Data("not json".utf8).write(to: url)
        XCTAssertNil(files.readState())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "the reader must not move another process's file")
    }

    func testWritingCreatesTheFolderWhenMissing() {
        let nested = folder.appendingPathComponent("nested/deeper")
        let files = SessionFiles(folder: nested)
        files.write(state: .idle, at: now)
        XCTAssertEqual(files.readState()?.state, .idle)
    }

    // MARK: Request (keyboard to app)

    func testRequestWrittenByTheKeyboardIsReadByTheApp() {
        // File dates are ISO 8601, which drops fractions of a second, so the test uses a whole second.
        let request = SessionRequest.make(.startCommand(on: "hey"), keyboardType: 7, contentType: nil, styleOverride: .formal,
                                          id: UUID(), sentAt: Date(timeIntervalSince1970: 1_800_000_000))
        SessionFiles(folder: folder).write(request: request)
        XCTAssertEqual(SessionFiles(folder: folder).readRequest(), request)
    }

    func testNoRequestFileReadsAsNil() {
        XCTAssertNil(SessionFiles(folder: folder).readRequest())
    }

    // MARK: Handled result

    func testTheHandledResultIsRemembered() {
        let id = UUID()
        let files = SessionFiles(folder: folder)
        XCTAssertNil(files.readHandledResult())
        files.markHandled(id)
        XCTAssertEqual(SessionFiles(folder: folder).readHandledResult(), id)
    }

    func testTheInboxIsRebuiltFromTheHandledFile() {
        let id = UUID()
        let files = SessionFiles(folder: folder)
        files.markHandled(id)
        XCTAssertEqual(files.inbox().handled, id)
    }
}

final class SessionClientTests: XCTestCase {
    private var folder: URL!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("session-client-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    private func client() -> SessionClient {
        SessionClient(files: SessionFiles(folder: folder), now: { [unowned self] in self.clock })
    }

    func testWithoutAStateFileTheSessionIsIdle() {
        XCTAssertEqual(client().state, .idle)
        XCTAssertFalse(client().isLive)
    }

    func testTheClientReadsWhatTheAppPublished() {
        SessionFiles(folder: folder).write(state: .ready(until: nil), at: clock)
        XCTAssertEqual(client().state, .ready(until: nil))
        XCTAssertTrue(client().isLive)
    }

    func testAStateThatWasNotRefreshedReadsAsIdle() {
        SessionFiles(folder: folder).write(state: .ready(until: nil), at: clock)
        clock = clock.addingTimeInterval(SessionLiveness.staleAfter + 1)
        XCTAssertEqual(client().state, .idle)
    }

    func testSendingWritesTheRequestWithTheFieldAndReturnsIt() {
        let sent = client().send(.start, field: FieldContext(kind: .email, styleOverride: .casual))
        XCTAssertEqual(SessionFiles(folder: folder).readRequest(), sent)
        XCTAssertEqual(sent.field, FieldContext(kind: .email, styleOverride: .casual))
        XCTAssertEqual(sent.sentAt, clock)
    }

    func testEachSendGetsANewID() {
        let c = client()
        XCTAssertNotEqual(c.send(.start, field: .general).id, c.send(.stop, field: .general).id)
    }

    func testPendingResultIsTakenOnlyOnce() {
        let files = SessionFiles(folder: folder)
        let id = UUID()
        files.write(state: .done(id: id, text: "hi "), at: clock)
        let c = client()
        let first = c.takePendingResult()
        XCTAssertEqual(first?.id, id)
        XCTAssertEqual(first?.text, "hi ")
        XCTAssertNil(c.takePendingResult())
        XCTAssertNil(client().takePendingResult(), "another keyboard instance must not insert it again")
    }
}

final class DarwinNotifierTests: XCTestCase {
    func testAPostedNotificationReachesTheObserver() {
        let name = "com.opensourceeverything.speakaway.tests.\(UUID().uuidString)"
        let received = expectation(description: "notification")
        let observer = DarwinObserver(name: name) { received.fulfill() }
        DarwinNotifier.post(name)
        wait(for: [received], timeout: 5)
        withExtendedLifetime(observer) {}
    }

    func testAStoppedObserverHearsNothing() {
        let name = "com.opensourceeverything.speakaway.tests.\(UUID().uuidString)"
        let silent = expectation(description: "no notification")
        silent.isInverted = true
        let observer = DarwinObserver(name: name) { silent.fulfill() }
        observer.stop()
        DarwinNotifier.post(name)
        wait(for: [silent], timeout: 0.5)
    }

    func testTwoObserversOfTheSameNameBothHearIt() {
        let name = "com.opensourceeverything.speakaway.tests.\(UUID().uuidString)"
        let a = expectation(description: "a")
        let b = expectation(description: "b")
        let first = DarwinObserver(name: name) { a.fulfill() }
        let second = DarwinObserver(name: name) { b.fulfill() }
        DarwinNotifier.post(name)
        wait(for: [a, b], timeout: 5)
        withExtendedLifetime((first, second)) {}
    }
}
