import AppKit
import SpeakAwayCore
import SwiftUI

/// The Speak Away mark: the speech bubble from the app icon with its three voice bars.
/// Geometry comes from the 1024 px icon (Resources/SpeakAway.icon/Assets).
enum BubbleMark {
    /// The bubble's bounding box on the 1024 canvas, tail included.
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
            let h = max(barWidth, tallest * bar.height)
            let lift = tallest * bar.lift
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

    /// Menu bar glyph: a solid bubble with the bars cut out, as a template image so macOS tints it.
    static func menuBarImage(_ bars: [BubbleMotion.Bar]) -> NSImage {
        let size = NSSize(width: 19, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let area = rect.insetBy(dx: 0.5, dy: 0.5)
            ctx.addPath(bubble(in: area))
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            ctx.setBlendMode(.clear)
            ctx.addPath(Self.bars(bars, in: area))
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Speak Away"
        return image
    }
}

/// The red bubble used in the HUD, with live bars.
struct BubbleView: View {
    let bars: [BubbleMotion.Bar]
    var fill = Color(red: 0.86, green: 0.23, blue: 0.25)

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(BubbleMark.bubble(in: rect)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.97, green: 0.40, blue: 0.42), fill]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            ctx.fill(Path(BubbleMark.bars(bars, in: rect)), with: .color(.white))
        }
    }
}
