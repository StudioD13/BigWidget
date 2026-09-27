import SwiftUI

/// A rounded Liquid Glass card that hosts one big readout.
struct GlassTile<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content

    private let shape = RoundedRectangle(cornerRadius: 44, style: .continuous)

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(visionOS)
            // visionOS has its own physical glass material with real depth.
            .glassBackgroundEffect(in: shape)
            #else
            .glassEffect(.clear.tint(tint.opacity(0.18)).interactive(), in: shape)
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

/// A big readout: small caption on top, huge bubbly value, and a footer underneath.
struct BigReadout<Footer: View>: View {
    var caption: String
    var value: String
    var tint: Color
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            Text(caption)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            GeometryReader { proxy in
                BubbleText(
                    text: value,
                    tint: tint,
                    size: BubbleText.fittingSize(for: value, in: proxy.size)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            footer
        }
    }
}

extension BigReadout where Footer == EmptyView {
    init(caption: String, value: String, tint: Color) {
        self.init(caption: caption, value: value, tint: tint) { EmptyView() }
    }
}
