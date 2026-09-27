import SwiftUI

/// Big, bubbly, 3D "candy glass" text — a playful take on Liquid Glass.
///
/// The effect is built from stacked copies of the same glyphs:
/// 1. An extruded "side wall" made of progressively darker slices, giving physical depth.
/// 2. A glossy face filled with a tinted gradient plus inner shadows that make it look inflated.
/// 3. A soft specular highlight across the upper half, like light hitting a glass bubble.
struct BubbleText: View {
    let text: String
    var tint: Color = .cyan
    var size: CGFloat = 120
    /// Widgets can't run keyframe animations, so they pass `false`.
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bounces: Bool { animated && !reduceMotion }

    /// Number of extrusion slices that form the 3D side of each glyph.
    private let depthSlices = 8

    private var font: Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    /// Vertical distance between extrusion slices.
    private var sliceOffset: CGFloat { size * 0.009 }

    var body: some View {
        ZStack {
            extrusion
            face
            gloss
        }
        .compositingGroup()
        // Colored drop shadow so the bubble appears to float above the glass tile.
        .shadow(color: tint.mix(with: .black, by: 0.55).opacity(0.45), radius: size * 0.06, y: size * 0.07)
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
                    tint.mix(with: .white, by: 0.6),
                    tint.mix(with: .white, by: 0.15),
                    tint,
                    tint.mix(with: .black, by: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Bright rim light along the top edges.
            .shadow(.inner(color: .white.opacity(0.85), radius: size * 0.018, x: 0, y: size * 0.022))
            // Darker bottom rim to round out the bubble.
            .shadow(.inner(color: tint.mix(with: .black, by: 0.55).opacity(0.7), radius: size * 0.03, x: 0, y: -size * 0.03))
        )
    }

    /// Soft specular shine sitting just inside the top of each glyph.
    private var gloss: some View {
        glyphs
            .foregroundStyle(
                LinearGradient(
                    colors: [.white.opacity(0.95), .white.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.5)
                )
            )
            // Masking with glyphs shifted down insets the shine away from the top rim.
            .mask { glyphs.offset(y: size * 0.045) }
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
    /// Picks the largest font size that lets `text` fit inside `available`.
    ///
    /// Width is estimated per character (in ems) for the black-weight rounded font. The visible height
    /// (~0.75em cap height plus extrusion) is much smaller than the line box, so slight line-box overflow is fine.
    static func fittingSize(for text: String, in available: CGSize) -> CGFloat {
        let ems = text.reduce(CGFloat.zero) { total, character in
            switch character {
            case ":", ".": total + 0.34
            case "%": total + 0.98
            case "-": total + 0.5
            default: total + 0.66
            }
        }
        // A little extra room for the drop shadow and edge highlights.
        let byWidth = available.width / (max(ems, 0.66) + 0.12)
        let byHeight = available.height / 1.1
        return max(12, min(byWidth, byHeight))
    }
}

#Preview {
    VStack(spacing: 40) {
        BubbleText(text: "10:42", tint: .cyan, size: 140)
        BubbleText(text: "27", tint: .pink, size: 140)
        BubbleText(text: "82%", tint: .green, size: 140)
    }
    .padding(40)
    .background(LinearGradient(colors: [.purple, .orange], startPoint: .top, endPoint: .bottom))
}
