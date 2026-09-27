import SwiftUI

/// A slowly drifting, colorful mesh gradient that gives the glass tiles something fun to refract.
struct LiquidBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: points(at: reduceMotion ? 0 : t),
                colors: colors
            )
        }
        .ignoresSafeArea()
    }

    /// Wobbles the interior mesh points on slow sine waves; the corners stay pinned.
    private func points(at t: TimeInterval) -> [SIMD2<Float>] {
        let a = Float(sin(t * 0.35)) * 0.15
        let b = Float(cos(t * 0.27)) * 0.15
        let c = Float(sin(t * 0.21 + 1)) * 0.1
        return [
            [0, 0], [0.5 + a, 0], [1, 0],
            [0, 0.5 + b], [0.5 + c, 0.5 - a], [1, 0.5 - c],
            [0, 1], [0.5 - b, 1], [1, 1]
        ]
    }

    private var colors: [Color] {
        if colorScheme == .dark {
            return [
                .indigo, .purple, .blue,
                .teal, .pink.mix(with: .black, by: 0.3), .indigo,
                .blue, .mint.mix(with: .black, by: 0.4), .purple
            ]
        } else {
            return [
                .cyan, .pink.opacity(0.8), .orange.opacity(0.8),
                .mint, .yellow.opacity(0.7), .pink,
                .blue.opacity(0.7), .teal, .purple.opacity(0.7)
            ]
        }
    }
}

#Preview {
    LiquidBackground()
}
