import Foundation

/// The Fn key state machine. A value type: each event returns the next state instead of changing this one.
///
/// Two modes, chosen at creation:
///
/// - Classic (`FnTap()`): double tap Fn to start, one tap to stop. Same timing as whisper-flow (0.4 s).
///   First press only remembers the time; the second press within `window` returns `.start`.
///   `release` does nothing.
///
/// - Push to talk (`FnTap(pushToTalk: true)`), like Wispr Flow:
///   hold Fn to dictate until you let go, double tap for hands-free, one tap to stop hands-free.
///
///   States: `idle(lastTap)` (Fn up, maybe a short tap just happened) and `holding(since)` (Fn down,
///   recording started by this press and not yet known to be a hold or a tap).
///
///   ```
///   idle      --press, recording--------------------------> idle       .stop    (stops hands-free)
///   idle      --press, last tap < 0.4 s ago---------------> idle       .start   (hands-free, double tap)
///   idle      --press otherwise---------------------------> holding    .startHold (record right away)
///   holding   --release after >= 0.35 s, recording--------> idle       .stop    (push to talk done)
///   holding   --release before 0.35 s, recording----------> idle(tap)  .discard (it was only a tap)
///   holding   --other key before 0.35 s, recording--------> idle       .discard (Fn used as a modifier)
///   holding   --other key after 0.35 s--------------------> holding    nothing  (keep dictating)
///   holding   --press, recording--------------------------> idle       .stop    (a release was missed)
///   idle      --release-----------------------------------> idle       nothing  (release of a stop or of
///                                                                                 the second tap: hands-free goes on)
///   ```
///
///   The recording starts on the first press so the first word is never lost. If it turns out to be a
///   short tap the app throws that audio away (`.discard`); a second tap within `window` of the
///   release starts a fresh hands-free recording (`.start`).
public struct FnTap: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        /// Start recording in hands-free mode (a double tap). Stays on until one more tap.
        case start
        /// Start recording at once because Fn is held (push to talk). Push-to-talk mode only.
        case startHold
        /// Stop recording and transcribe it.
        case stop
        /// Stop recording and throw the audio away (a short tap, or Fn used with another key).
        case discard
    }

    public static let window: TimeInterval = 0.4
    /// Held at least this long, a press is push to talk; shorter it is a tap.
    public static let holdThreshold: TimeInterval = 0.35

    private enum Phase: Equatable, Sendable {
        /// Fn is up. `lastTap` is when the last tap happened (press time in classic mode, release time in push to talk).
        case idle(lastTap: TimeInterval?)
        /// Fn is down and recording was started by this press.
        case holding(since: TimeInterval)
    }

    private let pushToTalk: Bool
    private let phase: Phase

    public init(pushToTalk: Bool = false) {
        self.pushToTalk = pushToTalk
        self.phase = .idle(lastTap: nil)
    }

    private init(pushToTalk: Bool, phase: Phase) {
        self.pushToTalk = pushToTalk
        self.phase = phase
    }

    private func idle(_ lastTap: TimeInterval? = nil) -> FnTap {
        FnTap(pushToTalk: pushToTalk, phase: .idle(lastTap: lastTap))
    }

    public func press(at time: TimeInterval, recording: Bool) -> (FnTap, Action?) {
        if recording { return (idle(), .stop) }
        if case .idle(let last?) = phase, time - last < FnTap.window {
            // Forget this tap so a quick third one is not read as another double tap.
            return (idle(), .start)
        }
        if pushToTalk {
            return (FnTap(pushToTalk: true, phase: .holding(since: time)), .startHold)
        }
        return (idle(time), nil)
    }

    /// Fn went up. Only push to talk reacts to it.
    public func release(at time: TimeInterval, recording: Bool) -> (FnTap, Action?) {
        guard pushToTalk, case .holding(let since) = phase else { return (self, nil) }
        if time - since >= FnTap.holdThreshold {
            return (idle(), recording ? .stop : nil)
        }
        return (idle(time), recording ? .discard : nil)
    }

    /// Fn used as a modifier (Fn + arrow, Fn + F-key): not a dictation tap.
    /// A push-to-talk hold in progress is kept; use `otherKey(at:recording:)` to also drop a tentative recording.
    public func otherKey() -> FnTap {
        if case .holding = phase { return self }
        return idle()
    }

    /// Like `otherKey()`, and when Fn was pressed only a moment ago (a chord, not a hold) it also asks to
    /// discard the recording that the press started.
    public func otherKey(at time: TimeInterval, recording: Bool) -> (FnTap, Action?) {
        guard case .holding(let since) = phase else { return (idle(), nil) }
        if time - since < FnTap.holdThreshold {
            return (idle(), recording ? .discard : nil)
        }
        return (self, nil)
    }
}
