import SwiftUI
import UIKit
import SpeakAwayCore

/// The look of the app: a light grey grouped background with white cards (true black with dark grey cards in
/// dark mode) and one red accent, the red of the icon. Every color is one token with a light and a dark value.
enum Theme {
    static let accent = dynamic(light: UIColor(red: 0.86, green: 0.23, blue: 0.25, alpha: 1),
                                dark: UIColor(red: 0.96, green: 0.33, blue: 0.35, alpha: 1))
    static let background = dynamic(light: UIColor(white: 0.945, alpha: 1), dark: .black)
    static let card = dynamic(light: .white, dark: UIColor(white: 0.11, alpha: 1))
    /// Empty cells of the activity grid, the track of progress bars, the bubble behind a message.
    static let track = dynamic(light: UIColor(white: 0.90, alpha: 1), dark: UIColor(white: 0.20, alpha: 1))
    static let cornerRadius: CGFloat = 22

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension View {
    /// The grouped background behind every screen.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

// MARK: Card

/// A white (dark grey in dark mode) rounded card.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

// MARK: Section header

/// The small grey title above a card, in capitals.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var trailing: LocalizedStringKey?

    var body: some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let trailing {
                Text(trailing).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }
}

// MARK: Pill

/// A dot and a short line in a capsule, for the state of the session.
struct Pill<Label: View>: View {
    let color: Color
    @ViewBuilder var label: () -> Label

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            label().font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.track.opacity(0.7), in: Capsule())
    }
}

// MARK: Stat

/// A big number with a small icon above it and a label below.
struct StatCard<Footer: View>: View {
    let icon: String
    let value: String
    let label: LocalizedStringKey
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(value)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label).font(.subheadline.weight(.medium))
                footer()
            }
        }
    }
}

/// A thin progress bar in the accent color.
struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(Theme.accent).frame(width: max(6, geometry.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: Empty state

struct EmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            Text(title).font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }
}

// MARK: The mark

/// The Speak Away mark: the speech bubble from the app icon with its three voice bars. Geometry comes from
/// the 1024 px icon, the same numbers the Mac app draws with.
enum BubbleMark {
    static let box = CGRect(x: 222, y: 262, width: 580, height: 506)
    static let barWidth: CGFloat = 84
    static let barCenters: [CGFloat] = [384, 512, 640]
    static let barMiddleY: CGFloat = 486
    static let tallest: CGFloat = 236

    /// The bubble outline, scaled to fit `rect` (y grows downwards, like the SVG).
    static func bubble(in rect: CGRect) -> CGPath {
        let t = transform(into: rect)
        let p = CGMutablePath()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y).applying(t) }
        p.move(to: pt(512, 262))
        p.addCurve(to: pt(802, 486), control1: pt(682, 262), control2: pt(802, 354))
        p.addCurve(to: pt(512, 710), control1: pt(802, 618), control2: pt(682, 710))
        p.addCurve(to: pt(416, 699), control1: pt(478, 710), control2: pt(446, 706))
        p.addLine(to: pt(304, 761))
        p.addCurve(to: pt(283, 743), control1: pt(292, 768), control2: pt(278, 756))
        p.addLine(to: pt(315, 657))
        p.addCurve(to: pt(222, 486), control1: pt(257, 616), control2: pt(222, 555))
        p.addCurve(to: pt(512, 262), control1: pt(222, 354), control2: pt(342, 262))
        p.closeSubpath()
        return p
    }

    /// The three bars for a moment of the animation, scaled to the same `rect`.
    static func bars(_ bars: [BubbleMotion.Bar], in rect: CGRect) -> CGPath {
        let t = transform(into: rect)
        let p = CGMutablePath()
        for (i, bar) in bars.enumerated() where i < barCenters.count {
            let h = max(barWidth, tallest * CGFloat(bar.height))
            let lift = tallest * CGFloat(bar.lift)
            let r = CGRect(x: barCenters[i] - barWidth / 2, y: barMiddleY - h / 2 - lift, width: barWidth, height: h)
            p.addRoundedRect(in: r, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: t)
        }
        return p
    }

    private static func transform(into rect: CGRect) -> CGAffineTransform {
        let s = min(rect.width / box.width, rect.height / box.height)
        let dx = rect.midX - box.midX * s
        let dy = rect.midY - box.midY * s
        return CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: dx, ty: dy)
    }
}

/// The red bubble with its white bars. At rest it is the logo.
struct BubbleView: View {
    var bars: [BubbleMotion.Bar] = BubbleMotion.bars(.idle, level: 0, time: 0)

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(BubbleMark.bubble(in: rect)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.97, green: 0.40, blue: 0.42), Color(red: 0.86, green: 0.23, blue: 0.25)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.fill(Path(BubbleMark.bars(bars, in: rect)), with: .color(.white))
        }
        .accessibilityHidden(true)
    }
}
