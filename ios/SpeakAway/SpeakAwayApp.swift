import SwiftUI
import SpeakAwayCore

@main
struct SpeakAwayApp: App {
    @StateObject private var model = AppModel()

    init() {
        SelfTest.runIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.session)
                .onOpenURL { model.open($0) }
        }
    }
}
