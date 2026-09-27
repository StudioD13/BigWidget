import SwiftUI

/// A rounded Liquid Glass card that hosts one big readout.
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
            .glassEffect(.regular.tint(tint.opacity(0.08)).interactive(), in: shape)
            #endif
    }
}

/// Groups tiles so their Liquid Glass renders together and can blend on platforms that support it.
struct TileGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        #if os(visionOS)
        content
        #else
        GlassEffectContainer(spacing: spacing) {
            content
        }
        #endif
    }
}

extension EnvironmentValues {
    /// Advances continuously in the app to move the light coursing through the neon tubes.
    @Entry var lightPhase: Double = 0
}

/// A big readout: optional small caption, a huge neon value that fills the space, and a footer.
struct BigReadout<Footer: View>: View {
    var caption: String?
    var value: String
    var tint: Color
    @ViewBuilder var footer: Footer

    @Environment(\.lightPhase) private var lightPhase

    var body: some View {
        VStack(spacing: 2) {
            if let caption {
                Text(caption)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(tint.mix(with: .primary, by: 0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            NeonText(text: value, color: tint, phase: lightPhase)

            footer
        }
    }
}
