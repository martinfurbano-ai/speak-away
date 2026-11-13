import SwiftUI
import SpeakAwayCore

/// The pill that says what the session is doing, with its colored dot.
struct SessionPill: View {
    let badge: SessionBadge

    var body: some View {
        Pill(color: color) { label }
    }

    private var color: Color {
        switch badge {
        case .off: return .gray
        case .ready: return .green
        case .listening: return Theme.accent
        case .writing: return .orange
        case .problem: return .red
        }
    }

    @ViewBuilder private var label: some View {
        switch badge {
        case .off:
            Text("Session off")
        case .ready(let minutes?):
            if minutes == 1 {
                Text("Ready to dictate · 1 min left")
            } else {
                Text("Ready to dictate · \(minutes) min left")
            }
        case .ready:
            Text("Ready to dictate")
        case .listening:
            Text("Listening")
        case .writing:
            Text("Writing it down")
        case .problem:
            Text("Something went wrong")
        }
    }
}

/// The session as the app sees it, refreshed every few seconds so "12 min left" counts down.
struct LiveSessionPill: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            SessionPill(badge: SessionBadge.make(state: session.state, sessionEnd: session.sessionEnd,
                                                 active: session.live, now: context.date))
        }
    }
}

/// What went wrong with the session, and the way out: the Settings app when the microphone is off.
struct SessionProblem: View {
    let message: String
    let needsSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(message).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .font(.subheadline)
            if needsSettings {
                Button("Open Settings") { SettingsLink.open() }
                    .buttonStyle(.glass)
            }
        }
    }
}

/// The bar shown while the speech model for the language is being fetched.
struct SpeechModelProgress: View {
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Getting the speech model ready").font(.footnote.weight(.medium))
                Spacer()
                Text(percent).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressBar(fraction: fraction)
        }
        .accessibilityElement(children: .combine)
    }

    private var percent: String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(UILanguage.locale))
    }
}
