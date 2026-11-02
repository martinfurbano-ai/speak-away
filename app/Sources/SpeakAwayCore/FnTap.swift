import Foundation

/// Double-tap Fn to start, tap Fn once to stop. Same timing as whisper-flow (0.4 s).
/// A value type: each press returns the next state instead of changing this one.
public struct FnTap: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case start, stop }

    public static let window: TimeInterval = 0.4
    let lastPress: TimeInterval?

    public init() { lastPress = nil }
    init(lastPress: TimeInterval?) { self.lastPress = lastPress }

    public func press(at time: TimeInterval, recording: Bool) -> (FnTap, Action?) {
        if recording { return (FnTap(lastPress: nil), .stop) }
        if let last = lastPress, time - last < FnTap.window {
            // Forget this tap so a quick third one is not read as another double tap.
            return (FnTap(lastPress: nil), .start)
        }
        return (FnTap(lastPress: time), nil)
    }

    /// Fn used as a modifier (Fn + arrow, Fn + F-key): not a dictation tap.
    public func otherKey() -> FnTap { FnTap(lastPress: nil) }
}
