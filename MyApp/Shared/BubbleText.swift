import SwiftUI

/// Big, bubbly, 3D "candy glass" text — a playful take on Liquid Glass.
///
/// The effect is built from stacked copies of the same glyphs:
/// 1. An extruded "side wall" made of progressively darker slices, giving physical depth.
/// 2. A glossy face filled with a tinted gradient plus inner shadows that make it look inflated.
/// 3. A soft specular highlight across the upper half, like light hitting a glass bubble.
///
/// Glyphs are stretched vertically (see `Fit`) so tall spaces are filled with tall numerals
/// instead of short, fat ones surrounded by blank space.
struct BubbleText: View {
    let text: String
    var tint: Color = .cyan
    var fit = Fit(size: 120, stretch: 1)
    /// Widgets can't run keyframe animations, so they pass `false`.
    var animated: Bool = true
    /// Draws plain single-color glyphs, for tinted/clear Home Screen widget styles.
    var flat: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bounces: Bool { animated && !reduceMotion }
    private var size: CGFloat { fit.size }

    /// Number of extrusion slices that form the 3D side of each glyph.
    private let depthSlices = 8

    private var font: Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    /// Vertical distance between extrusion slices. Divided by the stretch so the 3D depth stays
    /// smooth (no visible steps) after the glyphs are scaled vertically.
    private var sliceOffset: CGFloat { size * 0.009 / fit.stretch }

    var body: some View {
        ZStack {
            if flat {
                glyphs
            } else {
                extrusion
                face
                gloss
            }
        }
        .scaleEffect(x: 1, y: fit.stretch)
        // Report only the visible glyph height to layout, so there's no dead line-box space.
        .frame(height: size * Fit.visibleHeight * fit.stretch)
        .compositingGroup()
        // Soft colored drop shadow so the bubble floats above whatever is behind it.
        .shadow(color: flat ? .clear : tint.mix(with: .black, by: 0.6).opacity(0.3), radius: size * 0.04, y: size * 0.04)
        .modifier(BoingEffect(trigger: text, isEnabled: bounces))
        .animation(bounces ? .bouncy : nil, value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    // MARK: - Layers

    private var glyphs: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .contentTransition(.numericText())
    }

    /// Stacked slices that fake a solid extruded body under the face.
    private var extrusion: some View {
        ForEach(0..<depthSlices, id: \.self) { index in
            let darkness = 0.35 + 0.3 * Double(index) / Double(depthSlices)
            glyphs
                .foregroundStyle(tint.mix(with: .black, by: darkness))
                .offset(y: sliceOffset * CGFloat(depthSlices - index))
        }
    }

    /// The inflated, glassy front surface.
    private var face: some View {
        glyphs.foregroundStyle(
            LinearGradient(
                colors: [
                    tint.mix(with: .white, by: 0.55),
                    tint.mix(with: .white, by: 0.15),
                    tint,
                    tint.mix(with: .black, by: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Bright rim light along the top edges.
            .shadow(.inner(color: .white.opacity(0.8), radius: size * 0.018, x: 0, y: size * 0.022))
            // Darker bottom rim to round out the bubble.
            .shadow(.inner(color: tint.mix(with: .black, by: 0.55).opacity(0.65), radius: size * 0.03, x: 0, y: -size * 0.03))
        )
    }

    /// Soft specular shine sitting just inside the top of each glyph.
    private var gloss: some View {
        glyphs
            .foregroundStyle(
                LinearGradient(
                    colors: [.white.opacity(0.8), .white.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.5)
                )
            )
            // Masking with glyphs shifted down insets the shine away from the top rim.
            .mask { glyphs.offset(y: size * 0.045 / fit.stretch) }
            .blur(radius: size * 0.008)
            .blendMode(.plusLighter)
    }
}

/// A quick "boing" whenever the value changes. Skipped entirely when disabled (e.g. in widgets).
private struct BoingEffect: ViewModifier {
    let trigger: String
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.08, duration: 0.15, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy(extraBounce: 0.25))
            }
        } else {
            content
        }
    }
}

extension BubbleText {
    /// Font size plus vertical stretch that make `text` fill a space.
    struct Fit {
        var size: CGFloat
        var stretch: CGFloat

        /// Visible height of a digit (cap height + extrusion + a hair of margin), in ems.
        static let visibleHeight: CGFloat = 0.84

        /// Sizes by width first, then stretches glyphs vertically to use the leftover height
        /// (up to `maxStretch`). If height is the tighter constraint, no stretch is applied.
        init(_ text: String, in available: CGSize, maxStretch: CGFloat = 1.8) {
            // Per-character widths (in ems) for the black-weight rounded font.
            let ems = text.reduce(CGFloat.zero) { total, character in
                switch character {
                case ":", ".": total + 0.34
                case "%": total + 0.98
                case "-": total + 0.5
                default: total + 0.66
                }
            }
            let byWidth = available.width / (max(ems, 0.66) + 0.08)
            let byHeight = available.height / Self.visibleHeight

            if byWidth < byHeight {
                size = max(8, byWidth)
                stretch = min(byHeight / byWidth, maxStretch)
            } else {
                size = max(8, byHeight)
                stretch = 1
            }
        }

        init(size: CGFloat, stretch: CGFloat) {
            self.size = size
            self.stretch = stretch
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        BubbleText(text: "10:42", tint: .cyan, fit: .init(size: 110, stretch: 1.5))
        BubbleText(text: "27", tint: .pink, fit: .init(size: 110, stretch: 1.5))
        BubbleText(text: "82%", tint: .green, fit: .init(size: 110, stretch: 1.5))
    }
    .padding(30)
}
