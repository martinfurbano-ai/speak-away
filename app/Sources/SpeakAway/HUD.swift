import AppKit
import SpeakAwayCore
import SwiftUI

/// The floating pill at the bottom of the screen: orb, voice bars and state.
@MainActor
final class HUDModel: ObservableObject {
    enum Phase: Equatable { case hidden, listening, transcribing, pasted, note(String) }
    @Published var phase: Phase = .hidden
    @Published var level: Float = 0
}

struct HUDView: View {
    @ObservedObject var model: HUDModel
    private let accent = Color(red: 0.90, green: 0.28, blue: 0.30)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 12) {
                orb(t)
                bars(t)
                HStack(spacing: 7) {
                    Circle().fill(dotColor(t)).frame(width: 7, height: 7)
                    Text(label)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .kerning(0.6)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
            }
            .padding(.leading, 9)
            .padding(.trailing, 18)
            .frame(height: 52)
            .background(Capsule().fill(Color(white: 0.07)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.09), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var label: String {
        switch model.phase {
        case .hidden: return ""
        case .listening: return "ESCUCHANDO"
        case .transcribing: return "WHISPER"
        case .pasted: return "PEGADO"
        case .note(let text): return text
        }
    }

    private func dotColor(_ t: Double) -> Color {
        switch model.phase {
        case .listening: return Int(t * 2) % 2 == 0 ? accent : accent.opacity(0.25)
        case .pasted: return Color(red: 0.27, green: 0.76, blue: 0.48)
        case .note: return .orange
        default: return accent
        }
    }

    /// The logo bubble: bars follow the voice while listening, typing dots while Whisper writes.
    private func orb(_ t: Double) -> some View {
        let phase: BubbleMotion.Phase = model.phase == .listening ? .listening
            : model.phase == .transcribing ? .thinking : .idle
        return BubbleView(bars: BubbleMotion.bars(phase, level: model.level, time: t))
            .frame(width: 36, height: 32)
            .scaleEffect(model.phase == .listening ? 1 + CGFloat(model.level) * 0.06 : 1)
    }

    private func bars(_ t: Double) -> some View {
        let count = 16
        let level = model.phase == .listening ? Double(model.level) : (model.phase == .transcribing ? 0.08 : 0)
        return HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                let center = 1 - abs(Double(i) - Double(count - 1) / 2) / (Double(count) / 2)
                let wave = 0.5 + 0.5 * sin(t * 9 + Double(i) * 0.9) * sin(t * 3.7 + Double(i) * 0.4)
                Capsule().fill(.white.opacity(0.9))
                    .frame(width: 3, height: 4 + 22 * level * center * (0.35 + 0.65 * wave))
            }
        }
        .frame(height: 28)
    }
}

final class HUDPanel: NSPanel {
    init(model: HUDModel) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 360, height: 90),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = NSHostingView(rootView: HUDView(model: model))
    }

    func showOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.minY + 28))
        orderFrontRegardless()
    }
}
