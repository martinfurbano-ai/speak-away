import Foundation
import SpeakAwayCore

/// Sets macOS "Press Globe key to" to Do Nothing while Speak Away runs, and puts back the person's own
/// value when it quits. The plan comes from `FnKeyGuard`; this only reads and writes the preferences.
/// In the App Store sandbox the write cannot reach the system domain, and the guarding tap does the work.
enum FnSetting {
    private static let savedKey = "fnUsageTypeBeforeSpeakAway"
    private static let domain = FnKeyGuard.settingDomain as CFString
    private static let key = FnKeyGuard.settingKey as CFString

    static func takeOver() {
        let current = read()
        guard let plan = FnKeyGuard.takeOver(current: current) else { return }
        // Remember only the first time: after a crash the setting is already ours, keep the original.
        if FnKeyGuard.Saved(stored: UserDefaults.standard.object(forKey: savedKey) as? Int) == nil {
            UserDefaults.standard.set(plan.remember.stored, forKey: savedKey)
        }
        write(plan.write)
        DebugLog.write("globe key setting \(current.map(String.init) ?? "default") -> \(plan.write)")
    }

    static func restore() {
        guard let saved = FnKeyGuard.Saved(stored: UserDefaults.standard.object(forKey: savedKey) as? Int) else { return }
        switch FnKeyGuard.restore(saved) {
        case .write(let value): write(value)
        case .remove: write(nil)
        }
        UserDefaults.standard.removeObject(forKey: savedKey)
        DebugLog.write("globe key setting restored")
    }

    private static func read() -> Int? {
        CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Int
    }

    private static func write(_ value: Int?) {
        CFPreferencesSetValue(key, value.map { $0 as CFNumber }, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}
