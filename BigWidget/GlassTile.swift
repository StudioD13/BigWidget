import SwiftUI

/// A rounded card that hosts one big readout: black, with a faint outline in the readout's color.
struct GlassTile<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content

    private let shape = RoundedRectangle(cornerRadius: 44, style: .continuous)

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(visionOS)
            // visionOS has its own physical glass material with real depth.
            .glassBackgroundEffect(in: shape)
            #else
            .background(Color.black, in: shape)
            .overlay { shape.strokeBorder(tint.opacity(0.25), lineWidth: 1) }
            #endif
    }
}

/// Lays out a set of tiles (a plain container now that the tiles aren't glass).
struct TileGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
    }
}

extension EnvironmentValues {
    /// The neon colors chosen in the app.
    @Entry var neonStyle = NeonStyle()
}

/// A big readout: optional small caption, a huge neon value that fills the space, and a footer.
struct BigReadout<Footer: View>: View {
    var caption: String?
    var value: String
    var tint: Color
    @ViewBuilder var footer: Footer

    @Environment(\.neonStyle) private var neonStyle

    var body: some View {
        VStack(spacing: 2) {
            if let caption {
                Text(caption)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(tint.mix(with: .primary, by: 0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            DisplayText(text: value, color: tint, style: neonStyle)

            footer
        }
    }
}
