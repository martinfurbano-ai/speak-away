import AppKit

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if let flag = args.firstIndex(of: "--transcribe"), flag + 1 < args.count {
        SelfTest.run(path: args[flag + 1])
    }
    if let flag = args.firstIndex(of: "--preview-pill"), flag + 1 < args.count {
        Preview.pill(to: args[flag + 1])
    }
    if let flag = args.firstIndex(of: "--preview-home"), flag + 1 < args.count {
        Preview.home(to: args[flag + 1])
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
    app.run()
}
