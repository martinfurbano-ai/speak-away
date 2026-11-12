import SwiftUI
import SpeakAwayCore

/// The Speak Away mark as three bars. At rest it is the logo; while listening the bars follow the voice;
/// while thinking they bounce one after the other. The motion comes from `BubbleMotion`, shared with the Mac.
struct LevelBars: View {
    let phase: BubbleMotion.Phase
    var level: Double = 0
    var color: Color = .primary
    /// Height of the whole mark.
    var height: CGFloat = 40

    var body: some View {
        // A 20 fps clock is enough for the motion and cheap for a keyboard.
        TimelineView(.periodic(from: .now, by: phase == .idle ? 3600 : 1.0 / 20)) { context in
            let bars = BubbleMotion.bars(phase, level: Float(level), time: context.date.timeIntervalSinceReferenceDate)
            let width = height * CGFloat(BubbleMotion.dot)
            HStack(spacing: width * 0.55) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    Capsule()
                        .fill(color)
                        .frame(width: width, height: max(width, height * CGFloat(bar.height)))
                        .offset(y: -height * CGFloat(bar.lift))
                }
            }
            .frame(height: height * (1 + CGFloat(BubbleMotion.maxLift)))
        }
        .accessibilityHidden(true)
    }
}
