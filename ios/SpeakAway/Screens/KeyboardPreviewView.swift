import SwiftUI
import SpeakAwayCore

/// The keyboard drawn inside the app, at the size of the system keyboard, under a made-up chat. It exists for the
/// preview screens that make the store screenshots: the keys are the real ones, but nothing here talks to the
/// real keyboard, and every file the keys could touch is in the preview's own temporary folder.
struct KeyboardPreviewView: View {
    enum Moment {
        /// The session is on and the mic waits.
        case ready
        /// Listening to a dictation.
        case recording
        /// The text just landed in the field; Undo is available.
        case result
    }

    /// The system keyboard is 262 pt tall on a current iPhone in portrait.
    static let keyboardHeight: CGFloat = 262

    private let moment: Moment
    @StateObject private var keyboard: KeyboardModel

    init(moment: Moment, folder: URL) {
        self.moment = moment
        let state: SessionState
        switch moment {
        case .ready, .result: state = .ready(until: Date().addingTimeInterval(12 * 60))
        case .recording: state = .recording(level: 0.55)
        }
        _keyboard = StateObject(wrappedValue: KeyboardModel(preview: state, folder: folder, canUndo: moment == .result))
    }

    var body: some View {
        VStack(spacing: 0) {
            SampleChat(draft: moment == .result ? SampleChat.reply : nil)
            KeyboardView(model: keyboard, inputController: nil)
                .frame(height: Self.keyboardHeight)
                .frame(maxWidth: .infinity)
                .background(backdrop.ignoresSafeArea(edges: .bottom))
        }
        .screenBackground()
    }

    /// What the system draws behind the keys.
    private var backdrop: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.10, alpha: 1)
                : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
        })
    }
}

// MARK: Made-up chat

/// A chat with Carla Ruiz (a made-up person) for the keyboard screens. Its words are sample content in the language
/// of the phone, not interface text, so they are not in the string catalog.
private struct SampleChat: View {
    /// The text in the field, or `nil` for an empty field.
    let draft: String?

    static var reply: String {
        UILanguage.isSpanish
            ? "Mañana a las diez en la cafetería de siempre. Te veo allí."
            : "Tomorrow at ten at the usual café. See you there."
    }

    private var messages: [(text: String, mine: Bool)] {
        if UILanguage.isSpanish {
            return [("Hola, ¿confirmamos la reunión de mañana?", false),
                    ("Sí, claro. Te escribo ahora los detalles.", true),
                    ("¿A qué hora y dónde quedamos?", false)]
        }
        return [("Hi, shall we confirm tomorrow's meeting?", false),
                ("Yes, of course. I'll write the details now.", true),
                ("What time and where shall we meet?", false)]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                        bubble(message.text, mine: message.mine)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDisabled(true)
            composer
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.16)).frame(width: 46, height: 46)
                Text(verbatim: "CR").font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
            }
            Text(verbatim: "Carla Ruiz").font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.card)
    }

    private func bubble(_ text: String, mine: Bool) -> some View {
        HStack {
            if mine { Spacer(minLength: 56) }
            Text(verbatim: text)
                .font(.body)
                .foregroundStyle(mine ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(mine ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !mine { Spacer(minLength: 56) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Group {
                if let draft {
                    Text(verbatim: draft).foregroundStyle(Color.primary)
                } else {
                    Text(verbatim: UILanguage.isSpanish ? "Mensaje" : "Message").foregroundStyle(.tertiary)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.track, lineWidth: 1))
            ZStack {
                Circle().fill(draft == nil ? Theme.track : Theme.accent).frame(width: 36, height: 36)
                Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(draft == nil ? Color.secondary : Color.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
