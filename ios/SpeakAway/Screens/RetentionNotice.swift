import SwiftUI

/// Retention applies to history and meeting notes; the separate scratchpad is kept.
struct RetentionNotice: View {
    @EnvironmentObject private var store: PhoneStore

    var body: some View {
        if !store.settings.keepTranscripts {
            Text("Deleted automatically after 10 days. Change it in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
