import SwiftUI

/// A calm, mostly neutral backdrop. Two faint, slowly drifting glows give the glass tiles
/// something to catch without competing with the numbers.
struct LiquidBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    glow(.cyan, diameter: size.width * 0.9)
                        .position(x: size.width * (0.25 + 0.1 * sin(t * 0.12)), y: size.height * 0.2)
                    glow(.pink, diameter: size.width * 0.8)
                        .position(x: size.width * (0.8 + 0.08 * cos(t * 0.1)), y: size.height * 0.85)
                }
            }
        }
        #if os(macOS)
        // On Mac the window itself is translucent (see BigWidgetApp), so skip the solid fill.
        .background(.clear)
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .ignoresSafeArea()
    }

    private func glow(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.18))
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.3)
    }
}

#Preview {
    LiquidBackground()
}
