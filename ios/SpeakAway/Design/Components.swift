import SwiftUI

// MARK: Stat without a footer

extension StatCard where Footer == EmptyView {
    init(icon: String, value: String, label: LocalizedStringKey) {
        self.init(icon: icon, value: value, label: label) { EmptyView() }
    }
}

// MARK: Lists

extension View {
    /// A list on the grouped background, with white (dark grey) rows like the cards of the home screen.
    func appList() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }

    /// The card color for the rows of an `appList`.
    func cardRow() -> some View {
        listRowBackground(Theme.card)
    }
}

// MARK: Icon tile

/// The icon of a row: a symbol in a soft red rounded square.
struct IconTile: View {
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.accent.opacity(0.12))
                .frame(width: 40, height: 40)
            Image(systemName: systemName).foregroundStyle(Theme.accent)
        }
        .accessibilityHidden(true)
    }
}

// MARK: Numbered step

/// A numbered instruction: a soft red circle with the number, then the text.
struct NumberedStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: "\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accent.opacity(0.14), in: Circle())
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Toast

/// A short confirmation floating above the bottom of the screen ("Copied"). It clears itself.
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.snappy, value: message)
            .task(id: message) {
                guard message != nil else { return }
                try? await Task.sleep(for: .seconds(1.8))
                if !Task.isCancelled { message = nil }
            }
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

// MARK: Buttons

/// The wide main button of a card or a screen: Liquid Glass, tinted with the accent.
struct PrimaryButtonLabel: View {
    let title: LocalizedStringKey
    var systemImage: String?

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
