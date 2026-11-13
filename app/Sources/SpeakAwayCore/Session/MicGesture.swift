import Foundation

/// What the keyboard's mic key does for a touch: tap to start, tap to stop, or hold to talk
/// and release to stop. Every method returns a new gesture.
public struct MicGesture: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        /// No session: open the app to start one.
        case openApp
        case start
        case stop
        case none
    }

    /// Held at least this long, a press is hold-to-talk and its release stops the dictation.
    public static let holdSeconds: TimeInterval = 0.35
    /// After sending `start`, a `ready` state from the app is probably older than the request.
    public static let startGrace: TimeInterval = 1.5

    /// The keyboard believes a dictation is running (it sent `start` and no `stop` since).
    public let recording: Bool
    private let pressedAt: Date?
    private let startedByPress: Bool
    private let requestedAt: Date?

    public init(recording: Bool = false) {
        self.init(recording: recording, pressedAt: nil, startedByPress: false, requestedAt: nil)
    }

    private init(recording: Bool, pressedAt: Date?, startedByPress: Bool, requestedAt: Date?) {
        self.recording = recording
        self.pressedAt = pressedAt
        self.startedByPress = startedByPress
        self.requestedAt = requestedAt
    }

    public func pressed(at time: Date, state: SessionState) -> (MicGesture, Action) {
        if recording {
            return (MicGesture(recording: false, pressedAt: time, startedByPress: false, requestedAt: nil), .stop)
        }
        switch state {
        case .recording:
            return (MicGesture(recording: false, pressedAt: time, startedByPress: false, requestedAt: nil), .stop)
        case .ready, .done:
            return (MicGesture(recording: true, pressedAt: time, startedByPress: true, requestedAt: time), .start)
        case .transcribing:
            return (MicGesture(recording: false, pressedAt: nil, startedByPress: false, requestedAt: nil), .none)
        case .idle, .failed:
            return (MicGesture(recording: false, pressedAt: nil, startedByPress: false, requestedAt: nil), .openApp)
        case .meeting:
            // The microphone belongs to the meeting: the key only tells the user so.
            return (MicGesture(recording: false, pressedAt: nil, startedByPress: false, requestedAt: nil), .none)
        }
    }

    public func released(at time: Date) -> (MicGesture, Action) {
        guard let pressedAt else { return (self, .none) }
        if startedByPress, recording, time.timeIntervalSince(pressedAt) >= Self.holdSeconds {
            return (MicGesture(recording: false, pressedAt: nil, startedByPress: false, requestedAt: nil), .stop)
        }
        return (MicGesture(recording: recording, pressedAt: nil, startedByPress: false, requestedAt: requestedAt), .none)
    }

    /// Brings the gesture in line with what the app published.
    public func following(_ state: SessionState, at time: Date) -> MicGesture {
        switch state {
        case .recording:
            return MicGesture(recording: true, pressedAt: pressedAt, startedByPress: startedByPress, requestedAt: nil)
        case .ready, .done:
            if recording, let requestedAt, time.timeIntervalSince(requestedAt) < Self.startGrace { return self }
            return MicGesture(recording: false, pressedAt: pressedAt, startedByPress: startedByPress, requestedAt: nil)
        case .transcribing, .idle, .failed, .meeting:
            return MicGesture(recording: false, pressedAt: pressedAt, startedByPress: startedByPress, requestedAt: nil)
        }
    }
}
