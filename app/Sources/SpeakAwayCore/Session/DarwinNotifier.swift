import Foundation

/// Darwin notifications cross processes without carrying data: the keyboard and the app use them
/// to say "look at the shared file".
public enum DarwinNotifier {
    public static func post(_ name: String) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }
}

/// Calls `handler` on the main queue each time the named Darwin notification arrives, until `stop()` or release.
public final class DarwinObserver {
    private let name: String
    private let handler: () -> Void
    private let lock = NSLock()
    private var active = true

    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<DarwinObserver>.fromOpaque(observer).takeUnretainedValue().fire()
            },
            name as CFString, nil, .deliverImmediately)
    }

    public func stop() {
        lock.lock()
        let wasActive = active
        active = false
        lock.unlock()
        guard wasActive else { return }
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(), CFNotificationName(name as CFString), nil)
    }

    deinit { stop() }

    private var isActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return active
    }

    private func fire() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isActive else { return }
            self.handler()
        }
    }
}
