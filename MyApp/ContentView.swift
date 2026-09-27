import SwiftUI

/// The BigWidget dashboard. Lays out tiles based on the window's shape so it adapts
/// to resizable windows, split screen, and foldables like iPhone Duo (folded ↔ unfolded).
struct ContentView: View {
    @State private var battery = BatteryMonitor()

    private let spacing: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            TileGroup(spacing: spacing) {
                arrangement(for: proxy.size)
            }
            .padding(spacing)
        }
        #if !os(visionOS)
        .background { LiquidBackground() }
        #endif
        .task { await battery.run() }
    }

    @ViewBuilder
    private func arrangement(for size: CGSize) -> some View {
        let aspect = size.width / max(size.height, 1)

        if aspect > 1.6 {
            // Wide (landscape phone, Mac window): everything in a row, time gets extra room.
            let usable = size.width - spacing * 4
            HStack(spacing: spacing) {
                TimeWidget().frame(width: usable * 0.44)
                DateWidget().frame(width: usable * 0.28)
                BatteryWidget(monitor: battery).frame(width: usable * 0.28)
            }
        } else if aspect > 0.75 {
            // Roughly square (unfolded iPhone Duo, iPad): time across the top, two tiles below.
            VStack(spacing: spacing) {
                TimeWidget()
                HStack(spacing: spacing) {
                    DateWidget()
                    BatteryWidget(monitor: battery)
                }
            }
        } else {
            // Tall and narrow (folded phone, portrait): stacked, with time getting the biggest share.
            let usable = size.height - spacing * 4
            VStack(spacing: spacing) {
                TimeWidget().frame(height: usable * 0.38)
                DateWidget().frame(height: usable * 0.31)
                BatteryWidget(monitor: battery).frame(height: usable * 0.31)
            }
        }
    }
}

#Preview("Tall") {
    ContentView()
}

#Preview("Square", traits: .fixedLayout(width: 800, height: 760)) {
    ContentView()
}

#Preview("Wide", traits: .fixedLayout(width: 1100, height: 420)) {
    ContentView()
}
