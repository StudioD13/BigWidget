import SwiftUI

/// The BigWidget dashboard. Lays out tiles based on the window's shape so it adapts
/// to resizable windows, split screen, and foldables like iPhone Duo (folded ↔ unfolded).
struct ContentView: View {
    @State private var battery = BatteryMonitor()
    @State private var weather = WeatherMonitor()
    @State private var showsSettings = false

    @AppStorage(SharedStore.Key.scheme, store: SharedStore.defaults) private var scheme: NeonScheme = .classic
    @AppStorage(SharedStore.Key.effect, store: SharedStore.defaults) private var effect: NeonEffect = .coursing
    @AppStorage(SharedStore.Key.speed, store: SharedStore.defaults) private var speed: NeonSpeed = .normal

    @AppStorage(AppTile.time.storageKey) private var showTime = true
    @AppStorage(AppTile.date.storageKey) private var showDate = true
    @AppStorage(AppTile.weather.storageKey) private var showWeather = true
    @AppStorage(AppTile.battery.storageKey) private var showBattery = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let spacing: CGFloat = 16

    /// Base travel of the light per second, scaled by the Speed setting.
    private static let lightTravelPerSecond = 0.1

    var body: some View {
        // Continuously move the light coursing through the neon tubes (paused with Reduce Motion).
        TimelineView(.animation(paused: reduceMotion)) { context in
            GeometryReader { proxy in
                TileGroup(spacing: spacing) {
                    arrangement(for: proxy.size)
                }
                .padding(spacing)
            }
            .environment(\.lightPhase, reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * Self.lightTravelPerSecond * speed.multiplier)
            .environment(\.neonStyle, NeonStyle(scheme: scheme, effect: effect, speed: speed))
        }
        .overlay(alignment: .bottomTrailing) { settingsButton }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 480)
                #endif
        }
        #if !os(visionOS)
        .background { LiquidBackground() }
        #endif
        .task { await battery.run() }
        .task { await weather.run() }
    }

    private var settingsButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .padding(6)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Settings")
        .keyboardShortcut(",", modifiers: .command)
        .padding(spacing * 1.5)
    }

    private var visibleTiles: [AppTile] {
        let shown: [AppTile: Bool] = [.time: showTime, .date: showDate, .weather: showWeather, .battery: showBattery]
        let tiles = AppTile.allCases.filter { shown[$0] == true }
        return tiles.isEmpty ? [.time] : tiles
    }

    @ViewBuilder
    private func tile(_ tile: AppTile) -> some View {
        switch tile {
        case .time: TimeWidget()
        case .date: DateWidget()
        case .weather: WeatherWidget(monitor: weather)
        case .battery: BatteryWidget(monitor: battery)
        }
    }

    /// The first tile (usually the clock) gets extra room when there's more than one.
    private func share(of tile: AppTile, in tiles: [AppTile]) -> CGFloat {
        guard tiles.count > 1 else { return 1 }
        let lead: CGFloat = 1.4
        let total = lead + CGFloat(tiles.count - 1)
        return (tile == tiles.first ? lead : 1) / total
    }

    @ViewBuilder
    private func arrangement(for size: CGSize) -> some View {
        let tiles = visibleTiles
        let aspect = size.width / max(size.height, 1)

        if aspect > 1.6 {
            // Wide (landscape phone, Mac window): everything in a row.
            let usable = size.width - spacing * CGFloat(tiles.count + 1)
            HStack(spacing: spacing) {
                ForEach(tiles) { item in
                    tile(item).frame(width: usable * share(of: item, in: tiles))
                }
            }
        } else if aspect > 0.75 && tiles.count > 2 {
            // Roughly square (unfolded iPhone Duo, iPad): first tile across the top, the rest below.
            VStack(spacing: spacing) {
                tile(tiles[0])
                HStack(spacing: spacing) {
                    ForEach(tiles.dropFirst()) { tile($0) }
                }
            }
        } else {
            // Tall and narrow (folded phone, portrait): stacked.
            let usable = size.height - spacing * CGFloat(tiles.count + 1)
            VStack(spacing: spacing) {
                ForEach(tiles) { item in
                    tile(item).frame(height: usable * share(of: item, in: tiles))
                }
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
