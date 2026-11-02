import AppKit
import SpeakAwayCore
import SwiftUI

/// The pill at the bottom of the screen, always there like Wispr Flow's: a thin line when idle,
/// it grows into voice bars while you talk, typing dots while Whisper writes, and a check when it pastes.
@MainActor
final class HUDModel: ObservableObject {
    enum Phase: Equatable { case hidden, listening, transcribing, pasted, note(String) }
    @Published var phase: Phase = .hidden
    @Published var level: Float = 0
    /// Listening for a Command Mode instruction instead of dictation.
    @Published var command = false
    @Published var hovering = false
}

struct HUDView: View {
    @ObservedObject var model: HUDModel
    var onClick: () -> Void = {}

    private let accent = Color(red: 0.90, green: 0.28, blue: 0.30)
    private let spring = Animation.spring(response: 0.38, dampingFraction: 0.78)

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            TimelineView(.animation(paused: model.phase == .hidden && !model.hovering)) { timeline in
                pill(timeline.date.timeIntervalSinceReferenceDate)
            }
            .onHover { inside in withAnimation(spring) { model.hovering = inside } }
            .onTapGesture { onClick() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(spring, value: model.phase)
    }

    private var size: CGSize {
        switch model.phase {
        case .hidden: return model.hovering ? CGSize(width: 74, height: 22) : CGSize(width: 42, height: 9)
        case .note(let text): return CGSize(width: max(120, CGFloat(text.count) * 7.4 + 44), height: 30)
        default: return CGSize(width: 104, height: 30)
        }
    }

    private func pill(_ t: Double) -> some View {
        ZStack {
            Capsule().fill(Color.black.opacity(model.phase == .hidden && !model.hovering ? 0.55 : 0.88))
            Capsule().strokeBorder(Color.white.opacity(model.phase == .hidden && !model.hovering ? 0.4 : 0.22), lineWidth: 0.75)
            content(t).padding(.horizontal, 10)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(model.phase == .hidden ? 0.15 : 0.35), radius: model.phase == .hidden ? 3 : 10, y: 3)
        .contentShape(Capsule())
    }

    @ViewBuilder private func content(_ t: Double) -> some View {
        switch model.phase {
        case .hidden:
            if model.hovering {
                HStack(spacing: 5) {
                    key("fn"); key("fn")
                }
                .transition(.opacity)
            }
        case .listening:
            HStack(spacing: 8) {
                if model.command {
                    Image(systemName: "wand.and.stars").font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                } else {
                    Circle().fill(accent).frame(width: 6, height: 6).opacity(0.55 + 0.45 * abs(sin(t * 3)))
                }
                voiceBars(t)
            }
        case .transcribing:
            typingDots(t)
        case .pasted:
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(red: 0.36, green: 0.85, blue: 0.55))
        case .note(let text):
            Text(text).font(.system(size: 10.5, weight: .semibold, design: .rounded)).kerning(0.3)
                .foregroundStyle(.white.opacity(0.92)).lineLimit(1)
        }
    }

    private func key(_ label: String) -> some View {
        Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 4).padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.35), lineWidth: 0.75))
    }

    /// Eleven thin bars that follow the voice, tallest in the middle.
    private func voiceBars(_ t: Double) -> some View {
        let count = 11
        let level = Double(model.level)
        return HStack(spacing: 2.5) {
            ForEach(0..<count, id: \.self) { i in
                let center = 1 - abs(Double(i) - Double(count - 1) / 2) / (Double(count) / 2)
                let wave = 0.5 + 0.5 * sin(t * 10 + Double(i) * 0.85) * sin(t * 3.3 + Double(i) * 0.5)
                Capsule().fill(.white)
                    .frame(width: 2.5, height: 3 + 15 * min(1, level * 1.4) * (0.3 + 0.7 * center) * (0.35 + 0.65 * wave))
            }
        }
        .frame(height: 18)
    }

    /// The Speak Away dots: something about to be said.
    private func typingDots(_ t: Double) -> some View {
        let bars = BubbleMotion.bars(.thinking, level: 0, time: t)
        return HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(.white.opacity(0.9)).frame(width: 5, height: 5).offset(y: -CGFloat(bars[i].lift) * 22)
            }
        }
    }
}

final class HUDPanel: NSPanel {
    private static let panelSize = NSSize(width: 360, height: 54)

    init(model: HUDModel, onClick: @escaping () -> Void = {}) {
        super.init(contentRect: NSRect(origin: .zero, size: Self.panelSize),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: HUDView(model: model, onClick: onClick))
        host.frame = NSRect(origin: .zero, size: Self.panelSize)
        contentView = host
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        }
    }

    override var canBecomeKey: Bool { false }

    /// Bottom center of the screen with the mouse, just above the Dock. The panel itself is transparent;
    /// only the pill takes clicks, so nothing around it is blocked.
    func place() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.minY + 4))
    }

    func showOnActiveScreen() {
        place()
        orderFrontRegardless()
    }
}
