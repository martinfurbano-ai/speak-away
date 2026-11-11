import CoreGraphics
import Foundation
import SpeakAwayCore

/// Listens to the Fn (Globe) key anywhere in macOS. Needs Input Monitoring permission.
/// With Accessibility it also swallows the Fn key itself (`FnKeyGuard`), so macOS never opens the emoji
/// panel on top of the app where the dictation is about to be pasted.
///
/// The tap runs on its own thread, never on the main one. An active tap sits in front of every key press
/// on the Mac, including the Cmd+V that pastes a dictation: on the main thread any busy moment (starting
/// the microphone, saving the history) held those keys back, Fn presses arrived merged, and a late Cmd+V
/// pasted whatever the clipboard held by then. Callbacks get the time the key moved and run on this thread.
final class FnListener {
    /// Fn went down: when, and whether Control was held (Command Mode).
    var onFnDown: ((TimeInterval, Bool) -> Void)?
    var onFnUp: ((TimeInterval) -> Void)?
    var onOtherKey: ((TimeInterval) -> Void)?
    private(set) var isRunning = false
    /// True when the tap can drop events (Accessibility granted), false when it only listens.
    private(set) var isGuarding = false
    /// True when Control was held as Fn went down: Wispr Flow style Command Mode.
    private(set) var commandHeld = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var fnDown = false

    /// The run loop of the listener's own thread, started on first use.
    private lazy var runLoop: CFRunLoop = {
        var loop: CFRunLoop?
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread {
            loop = CFRunLoopGetCurrent()
            // A run loop without sources returns at once: a port keeps it alive.
            RunLoop.current.add(NSMachPort(), forMode: .default)
            ready.signal()
            RunLoop.current.run()
        }
        thread.name = "Speak Away keys"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return loop!
    }()

    /// Starts listening, guarding the Fn key when macOS allows it. Called again later it upgrades a
    /// listen-only tap to a guarding one once Accessibility is granted.
    @discardableResult
    func start() -> Bool {
        if isRunning && isGuarding { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
        if let tap = makeTap(.defaultTap, mask: mask) {
            install(tap, guarding: true)
            return true
        }
        if isRunning { return true }
        guard let tap = makeTap(.listenOnly, mask: mask) else { return false }
        install(tap, guarding: false)
        return true
    }

    private func makeTap(_ options: CGEventTapOptions, mask: Int) -> CFMachPort? {
        CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let listener = Unmanaged<FnListener>.fromOpaque(refcon).takeUnretainedValue()
                return listener.handle(type, event) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func install(_ newTap: CFMachPort, guarding: Bool) {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(runLoop, source, .commonModes) }
        let newSource = CFMachPortCreateRunLoopSource(nil, newTap, 0)
        CFRunLoopAddSource(runLoop, newSource, .commonModes)
        CFRunLoopWakeUp(runLoop)
        CGEvent.tapEnable(tap: newTap, enable: true)
        DebugLog.write(guarding ? "fn listener on, guarding the Fn key" : "fn listener on, listen only")
        tap = newTap
        source = newSource
        isGuarding = guarding
        isRunning = true
    }

    /// Handles one event. Returns true when the event must not reach other apps.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        // macOS switches the tap off when it is slow or for security; switch it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        let time = ProcessInfo.processInfo.systemUptime
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let swallow = isGuarding && FnKeyGuard.swallows(Self.kind(type), keyCode: code)
        if type == .keyUp { return swallow }
        if type == .keyDown {
            // The Fn/Globe key itself can arrive as a key press (63 or 179); it must not count as "another key".
            if code == FnKeyGuard.fnKeyCode || code == FnKeyGuard.globeKeyCode { return swallow }
            onOtherKey?(time)
            return false
        }
        let down = event.flags.contains(.maskSecondaryFn)
        if down && !fnDown {
            commandHeld = event.flags.contains(.maskControl)
            DebugLog.write("fn down\(commandHeld ? " +control" : "")")
            onFnDown?(time, commandHeld)
        }
        if !down && fnDown { DebugLog.write("fn up"); onFnUp?(time) }
        fnDown = down
        return swallow
    }

    private static func kind(_ type: CGEventType) -> FnKeyGuard.EventKind {
        switch type {
        case .flagsChanged: return .flagsChanged
        case .keyDown: return .keyDown
        case .keyUp: return .keyUp
        default: return .other
        }
    }
}
