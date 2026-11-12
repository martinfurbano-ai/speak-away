import SwiftUI
import SpeakAwayCore

/// What the keyboard view shows and does. The view controller fills in the actions.
final class KeyboardModel: ObservableObject {
    @Published var category: AppCategory = .messages
    var showsGlobe = true
    var insert: (String) -> Void = { _ in }
    var deleteBackward: () -> Void = {}
    var nextKeyboard: () -> Void = {}
}

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 10) {
            Text("Style: \(model.category.rawValue)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Placeholder: the mic is wired to the session bridge in the next step.
            Button {} label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(Color.red))
            }
            .accessibilityLabel("Dictate")

            HStack(spacing: 8) {
                if model.showsGlobe {
                    key(systemImage: "globe", label: "Next keyboard", width: 56) { model.nextKeyboard() }
                }
                key(title: "space", label: "Space") { model.insert(" ") }
                key(systemImage: "delete.left", label: "Delete", width: 56) { model.deleteBackward() }
                key(systemImage: "return", label: "Return", width: 56) { model.insert("\n") }
            }
            .frame(height: 46)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func key(title: String? = nil, systemImage: String? = nil, label: String, width: CGFloat? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(title ?? "")
                }
            }
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.primary)
            .frame(maxWidth: width == nil ? .infinity : width, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .systemBackground).opacity(0.7)))
        }
        .frame(width: width)
        .accessibilityLabel(label)
    }
}
