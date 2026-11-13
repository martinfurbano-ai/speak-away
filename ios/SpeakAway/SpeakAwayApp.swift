import SwiftUI
import SpeakAwayCore

@main
struct SpeakAwayApp: App {
    @StateObject private var model: AppModel

    init() {
        SelfTest.runIfRequested()
        if let request = PreviewRequest(arguments: ProcessInfo.processInfo.arguments) {
            _model = StateObject(wrappedValue: AppModel(preview: request))
        } else {
            _model = StateObject(wrappedValue: AppModel())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.session)
                .environmentObject(model.store)
                .environmentObject(model.noteDictation)
                .tint(Theme.accent)
                .preferredColorScheme(model.forcedScheme)
                .onOpenURL { model.open($0) }
        }
    }
}
