import CoreGraphics
import Foundation

/// Listens to the Fn (Globe) key anywhere in macOS. Needs Input Monitoring permission.
final class FnListener {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?
    var onOtherKey: (() -> Void)?
    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var fnDown = false

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                if let refcon {
                    Unmanaged<FnListener>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        isRunning = true
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        // macOS switches the tap off when it is slow or for security; switch it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if type == .keyDown {
            onOtherKey?()
            return
        }
        let down = event.flags.contains(.maskSecondaryFn)
        if down && !fnDown { onFnDown?() }
        if !down && fnDown { onFnUp?() }
        fnDown = down
    }
}
