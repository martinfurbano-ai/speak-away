import AppKit

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if let flag = args.firstIndex(of: "--transcribe"), flag + 1 < args.count {
        SelfTest.run(path: args[flag + 1])
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
    app.run()
}
