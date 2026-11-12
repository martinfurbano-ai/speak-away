import XCTest
@testable import SpeakAwayCore

final class SharedContainerTests: XCTestCase {
    private let group = URL(fileURLWithPath: "/private/var/mobile/Containers/Shared/AppGroup/ABC")
    private let fallback = URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application/XYZ/Library/Application Support/Speak Away")

    func testTheGroupFolderIsUsedWhenItExists() {
        XCTAssertEqual(SharedContainer.resolve(groupURL: group, fallback: fallback), group)
    }

    func testTheAppsOwnFolderIsTheFallbackWhenTheGroupIsMissing() {
        XCTAssertEqual(SharedContainer.resolve(groupURL: nil, fallback: fallback), fallback)
    }

    func testFilesLiveDirectlyInTheFolder() {
        let url = SharedContainer.file(SharedFiles.history, in: group)
        XCTAssertEqual(url.deletingLastPathComponent().path, group.path)
        XCTAssertEqual(url.lastPathComponent, "history.json")
    }

    func testEveryFileNameIsUniqueAndJSON() {
        let names = [SharedFiles.settings, SharedFiles.dictionary, SharedFiles.snippets, SharedFiles.style,
                     SharedFiles.history, SharedFiles.stats, SessionChannel.requestFile, SessionChannel.stateFile,
                     SharedFiles.handledResult]
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(names.allSatisfy { $0.hasSuffix(".json") })
    }

    func testTheDefaultFolderAlwaysResolves() {
        // Without the entitlement (unit tests) it is the fallback, but it is never empty.
        XCTAssertFalse(SharedContainer.directory.path.isEmpty)
    }

    func testTheAppGroupIDMatchesTheEntitlements() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for path in ["ios/SpeakAway/SpeakAway.entitlements", "ios/SpeakAwayKeyboard/SpeakAwayKeyboard.entitlements"] {
            let url = root.appendingPathComponent(path)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "the iOS project is not in this checkout")
            XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains(SessionChannel.appGroupID), path)
        }
    }
}
