import SwiftUI
import SpeakAwayBrain

@main
struct SpeakAwayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Placeholder home screen. The real screens arrive with the session bridge.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Speak Away")
                .font(.largeTitle.weight(.semibold))
            // Proves the SpeakAwayBrain framework is linked into the app.
            Text(LocalBrain.availability.isUsable ? "On-device brain ready" : "On-device brain not available")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
