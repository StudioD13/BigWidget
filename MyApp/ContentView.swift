import SwiftUI

/// The BigWidget dashboard. Lays out tiles based on the window's shape so it adapts
/// to resizable windows, split screen, and foldables like iPhone Duo (folded ↔ unfolded).
struct ContentView: View {
    @State private var battery = BatteryMonitor()
    @State private var weather = WeatherMonitor()
    @AppStorage("neonScheme") private var scheme: NeonScheme = .classic
    @AppStorage("neonEffect") private var effect: NeonEffect = .coursing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let spacing: CGFloat = 16

    var body: some View {
        // Continuously move the light coursing through the neon tubes (paused with Reduce Motion).
        TimelineView(.animation(paused: reduceMotion)) { context in
            GeometryReader { proxy in
                TileGroup(spacing: spacing) {
                    arrangement(for: proxy.size)
                }
                .padding(spacing)
            }
            .environment(\.lightPhase, reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 0.08)
            .environment(\.neonStyle, NeonStyle(scheme: scheme, effect: effect))
        }
        .overlay(alignment: .bottomTrailing) { styleMenu }
        #if !os(visionOS)
        .background { LiquidBackground() }
        #endif
        .task { await battery.run() }
        .task { await weather.run() }
    }

    /// Lets people play with the neon colors and light effects.
    private var styleMenu: some View {
        Menu {
            Picker("Colors", selection: $scheme) {
                ForEach(NeonScheme.allCases, id: \.self) { Text($0.title) }
            }
            Picker("Effect", selection: $effect) {
                ForEach(NeonEffect.allCases, id: \.self) { Text($0.title) }
            }
        } label: {
            Image(systemName: "paintpalette.fill")
                .font(.title2)
                .padding(6)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Neon style")
        .padding(spacing * 1.5)
    }

    @ViewBuilder
    private func arrangement(for size: CGSize) -> some View {
        let aspect = size.width / max(size.height, 1)

        if aspect > 1.6 {
            // Wide (landscape phone, Mac window): everything in a row, time gets extra room.
            let usable = size.width - spacing * 5
            HStack(spacing: spacing) {
                TimeWidget().frame(width: usable * 0.34)
                DateWidget().frame(width: usable * 0.22)
                WeatherWidget(monitor: weather).frame(width: usable * 0.22)
                BatteryWidget(monitor: battery).frame(width: usable * 0.22)
            }
        } else if aspect > 0.75 {
            // Roughly square (unfolded iPhone Duo, iPad): time across the top, three tiles below.
            VStack(spacing: spacing) {
                TimeWidget()
                HStack(spacing: spacing) {
                    DateWidget()
                    WeatherWidget(monitor: weather)
                    BatteryWidget(monitor: battery)
                }
            }
        } else {
            // Tall and narrow (folded phone, portrait): stacked, with time getting the biggest share.
            let usable = size.height - spacing * 5
            VStack(spacing: spacing) {
                TimeWidget().frame(height: usable * 0.31)
                DateWidget().frame(height: usable * 0.23)
                WeatherWidget(monitor: weather).frame(height: usable * 0.23)
                BatteryWidget(monitor: battery).frame(height: usable * 0.23)
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
