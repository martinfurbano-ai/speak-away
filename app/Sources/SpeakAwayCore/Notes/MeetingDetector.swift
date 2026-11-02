import Foundation

public struct MeetingApp: Equatable, Hashable, Codable, Sendable {
    public let bundleID: String
    public let name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// Decides if a call is probably going on, from which apps run and which of them hold the microphone.
public enum MeetingDetector {
    struct Known {
        let bundleID: String
        let name: String
        /// Dedicated call apps may be guessed from "mic busy and the app is open".
        /// Slack, WhatsApp and browsers are open all day, so they only count when we know they hold the mic.
        let dedicated: Bool
    }

    /// In priority order, so the answer never depends on set ordering.
    static let known: [Known] = [
        Known(bundleID: "us.zoom.xos", name: "Zoom", dedicated: true),
        Known(bundleID: "zoom.us", name: "Zoom", dedicated: true),
        Known(bundleID: "com.microsoft.teams2", name: "Microsoft Teams", dedicated: true),
        Known(bundleID: "com.microsoft.teams", name: "Microsoft Teams", dedicated: true),
        Known(bundleID: "com.apple.FaceTime", name: "FaceTime", dedicated: true),
        Known(bundleID: "com.cisco.webexmeetings", name: "Webex", dedicated: true),
        Known(bundleID: "Cisco-Systems.Spark", name: "Webex", dedicated: true),
        Known(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", dedicated: false),
        Known(bundleID: "net.whatsapp.WhatsApp", name: "WhatsApp", dedicated: false),
    ]

    public static let browsers: Set<String> = [
        "com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "com.microsoft.edgemac",
        "company.thebrowser.Browser", "com.brave.Browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
    ]

    public static let ownBundleID = "com.opensourceeverything.speakaway"

    /// - Parameters:
    ///   - running: bundle IDs of the running apps.
    ///   - micUsers: bundle IDs of processes holding the microphone. Empty when the system cannot tell (before macOS 14.2).
    ///   - micInUse: the default input device is running for someone.
    ///   - meetBrowsers: browsers known to show a Google Meet call. Only filled when the caller can really tell.
    public static func detect(running: Set<String>, micUsers: Set<String>, micInUse: Bool, meetBrowsers: Set<String> = []) -> MeetingApp? {
        let attributed = !micUsers.isEmpty
        let others = micUsers.subtracting([ownBundleID])

        if attributed {
            if let hit = known.first(where: { others.contains($0.bundleID) }) {
                return MeetingApp(bundleID: hit.bundleID, name: hit.name)
            }
            if let browser = others.filter({ browsers.contains($0) && meetBrowsers.contains($0) }).sorted().first {
                return MeetingApp(bundleID: browser, name: "Google Meet")
            }
            return nil
        }

        guard micInUse else { return nil }
        if let hit = known.first(where: { $0.dedicated && running.contains($0.bundleID) }) {
            return MeetingApp(bundleID: hit.bundleID, name: hit.name)
        }
        return nil
    }
}

/// Turns the 5 s polls into "a meeting started" and "the meeting ended", without flicker.
/// Two sightings in a row start it, three misses in a row end it, and it announces once per meeting.
public struct MeetingPresence: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case started(MeetingApp)
        case ended
    }

    public static let hitsToStart = 2
    public static let missesToEnd = 3

    public let current: MeetingApp?
    let candidate: MeetingApp?
    let hits: Int
    let misses: Int

    public init() { self.init(current: nil, candidate: nil, hits: 0, misses: 0) }

    private init(current: MeetingApp?, candidate: MeetingApp?, hits: Int, misses: Int) {
        self.current = current
        self.candidate = candidate
        self.hits = hits
        self.misses = misses
    }

    public func observing(_ app: MeetingApp?) -> (MeetingPresence, Event?) {
        if let current {
            guard app != nil else {
                let missed = misses + 1
                if missed >= MeetingPresence.missesToEnd { return (MeetingPresence(), .ended) }
                return (MeetingPresence(current: current, candidate: nil, hits: 0, misses: missed), nil)
            }
            return (MeetingPresence(current: current, candidate: nil, hits: 0, misses: 0), nil)
        }
        guard let app else { return (MeetingPresence(), nil) }
        let streak = candidate == app ? hits + 1 : 1
        if streak >= MeetingPresence.hitsToStart {
            return (MeetingPresence(current: app, candidate: nil, hits: 0, misses: 0), .started(app))
        }
        return (MeetingPresence(current: nil, candidate: app, hits: streak, misses: 0), nil)
    }
}
