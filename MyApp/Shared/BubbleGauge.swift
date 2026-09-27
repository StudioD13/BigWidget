import SwiftUI

/// A glossy capsule that fills like a bubble level.
struct BubbleGauge: View {
    var level: Double
    var tint: Color
    var isCharging: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.15).shadow(.inner(color: .black.opacity(0.35), radius: 3, y: 2)))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.mix(with: .white, by: 0.5), tint, tint.mix(with: .black, by: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .shadow(.inner(color: .white.opacity(0.8), radius: 2, y: 3))
                    )
                    .frame(width: max(proxy.size.height, proxy.size.width * level))
                    .animation(.bouncy, value: level)

                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: proxy.size.height * 0.7, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .frame(maxWidth: .infinity)
                        .symbolEffect(.pulse)
                }
            }
        }
    }
}
