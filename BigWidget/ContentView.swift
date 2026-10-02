import SwiftUI

/// The BigWidget dashboard. Lays out tiles based on the window's shape so it adapts
/// to resizable windows, split screen, and foldables like iPhone Duo (folded ↔ unfolded).
struct ContentView: View {
    @State private var battery = BatteryMonitor()
    @State private var weather = WeatherMonitor()
    @State private var showsSettings = false

    @AppStorage(SharedStore.Key.scheme, store: SharedStore.defaults) private var scheme: NeonScheme = .classic
    @AppStorage(SharedStore.Key.numbers, store: SharedStore.defaults) private var numbers: NumberStyle = .normal
    @AppStorage(SharedStore.Key.bloom, store: SharedStore.defaults) private var bloom: NeonBloom = .soft
    @AppStorage(SharedStore.Key.thickness, store: SharedStore.defaults) private var thickness: NumberThickness = .regular
    @AppStorage(SharedStore.Key.isRandom, store: SharedStore.defaults) private var isRandom = false

    @AppStorage(AppTile.time.storageKey, store: SharedStore.defaults) private var showTime = true
    @AppStorage(AppTile.date.storageKey, store: SharedStore.defaults) private var showDate = true
    @AppStorage(AppTile.weather.storageKey, store: SharedStore.defaults) private var showWeather = true
    @AppStorage(AppTile.battery.storageKey, store: SharedStore.defaults) private var showBattery = true

    private let spacing: CGFloat = 16

    var body: some View {
        // Ticks once a minute so Random can move to a new look; otherwise just redraws the
        // (identical) style, which costs nothing.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            GeometryReader { proxy in
                TileGroup(spacing: spacing) {
                    arrangement(for: proxy.size, date: context.date)
                }
                .padding(spacing)
            }
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

    /// The look to draw a tile with: a new, independent random combination every minute for each
    /// tile (Random), or the one chosen manually, shared by all tiles. Widgets compute this the same
    /// way, so a Match App widget lands on the same look without needing the app to be open.
    private func currentStyle(for tile: AppTile, at date: Date) -> NeonStyle {
        isRandom ? .random(for: date, element: tile.randomSeed) : NeonStyle(scheme: scheme, numbers: numbers, bloom: bloom, thickness: thickness)
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
    private func tile(_ tile: AppTile, at date: Date) -> some View {
        Group {
            switch tile {
            case .time: TimeWidget()
            case .date: DateWidget()
            case .weather: WeatherWidget(monitor: weather)
            case .battery: BatteryWidget(monitor: battery)
            }
        }
        .environment(\.neonStyle, currentStyle(for: tile, at: date))
    }

    /// Time gets extra room whenever it's shown — it's the thing people check most — split evenly
    /// otherwise.
    private func share(of tile: AppTile, in tiles: [AppTile]) -> CGFloat {
        guard tiles.count > 1 else { return 1 }
        guard tiles.contains(.time) else { return 1 / CGFloat(tiles.count) }
        let lead: CGFloat = 1.6
        let total = lead + CGFloat(tiles.count - 1)
        return (tile == .time ? lead : 1) / total
    }

    @ViewBuilder
    private func arrangement(for size: CGSize, date: Date) -> some View {
        let tiles = visibleTiles
        let aspect = size.width / max(size.height, 1)

        if aspect > 1.6 {
            // Wide (landscape phone, Mac window): everything in a row.
            let usable = size.width - spacing * CGFloat(tiles.count + 1)
            HStack(spacing: spacing) {
                ForEach(tiles) { item in
                    tile(item, at: date).frame(width: usable * share(of: item, in: tiles))
                }
            }
        } else if aspect > 0.75 && tiles.count > 2 {
            // Roughly square (unfolded iPhone Duo, iPad): Time across the top, given size
            // priority, the rest below. (Time is always first among the tiles, when shown.)
            let usableHeight = size.height - spacing
            let topShare = tiles.first == .time ? 1.6 / 2.6 : 0.5
            VStack(spacing: spacing) {
                tile(tiles[0], at: date).frame(height: usableHeight * topShare)
                HStack(spacing: spacing) {
                    ForEach(tiles.dropFirst()) { tile($0, at: date) }
                }
                .frame(height: usableHeight * (1 - topShare))
            }
        } else {
            // Tall and narrow (folded phone, portrait): stacked.
            let usable = size.height - spacing * CGFloat(tiles.count + 1)
            VStack(spacing: spacing) {
                ForEach(tiles) { item in
                    tile(item, at: date).frame(height: usable * share(of: item, in: tiles))
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
