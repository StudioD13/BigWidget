import SwiftUI
import WidgetKit

/// App preferences. The neon style is stored in the shared App Group, so widgets set to
/// "Match App Style" pick up changes immediately.
struct SettingsView: View {
    @AppStorage(SharedStore.Key.scheme, store: SharedStore.defaults) private var scheme: NeonScheme = .white
    @AppStorage(SharedStore.Key.numbers, store: SharedStore.defaults) private var numbers: NumberStyle = .normal
    @AppStorage(SharedStore.Key.bloom, store: SharedStore.defaults) private var bloom: NeonBloom = .soft
    @AppStorage(SharedStore.Key.thickness, store: SharedStore.defaults) private var thickness: NumberThickness = .regular
    @AppStorage(SharedStore.Key.isRandom, store: SharedStore.defaults) private var isRandom = false

    @AppStorage(AppTile.time.storageKey, store: SharedStore.defaults) private var showTime = true
    @AppStorage(AppTile.date.storageKey, store: SharedStore.defaults) private var showDate = true
    @AppStorage(AppTile.weather.storageKey, store: SharedStore.defaults) private var showWeather = true
    @AppStorage(AppTile.battery.storageKey, store: SharedStore.defaults) private var showBattery = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Time", isOn: $showTime)
                    Toggle("Date", isOn: $showDate)
                    Toggle("Weather", isOn: $showWeather)
                    Toggle("Battery", isOn: $showBattery)
                } header: {
                    Text("Show")
                } footer: {
                    Text("Widgets set to Match App show these too. To give a widget its own readouts and look, touch and hold it, choose Edit Widget, and turn off Match App.")
                }

                Section {
                    Toggle("Random", isOn: $isRandom)
                    if !isRandom {
                        Picker("Numbers", selection: $numbers) {
                            ForEach(NumberStyle.allCases, id: \.self) { Text($0.title) }
                        }
                        Picker("Thickness", selection: $thickness) {
                            ForEach(NumberThickness.allCases, id: \.self) { Text($0.title) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Colors", selection: $scheme) {
                            ForEach(NeonScheme.allCases, id: \.self) { Text($0.title) }
                        }
                        if numbers.usesBloom {
                            Picker("Bloom", selection: $bloom) {
                                ForEach(NeonBloom.allCases, id: \.self) { Text($0.title) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                } header: {
                    Text("Look")
                } footer: {
                    Text(isRandom
                        ? "Numbers, thickness, colors, and bloom change to a new random combination every minute."
                        : "Widgets set to Match App use these too.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: showTime) { reloadWidgets() }
        .onChange(of: showDate) { reloadWidgets() }
        .onChange(of: showWeather) { reloadWidgets() }
        .onChange(of: showBattery) { reloadWidgets() }
        .onChange(of: scheme) { reloadWidgets() }
        .onChange(of: numbers) { reloadWidgets() }
        .onChange(of: bloom) { reloadWidgets() }
        .onChange(of: thickness) { reloadWidgets() }
        .onChange(of: isRandom) { reloadWidgets() }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// The tiles the app can show, in display order.
enum AppTile: String, CaseIterable, Identifiable {
    case time, date, weather, battery

    var id: Self { self }
    var storageKey: String { SharedStore.showKey(rawValue) }

    /// A stable per-tile number, so Random can give each tile its own independent combination
    /// instead of all of them sharing one.
    var randomSeed: Int {
        switch self {
        case .time: 0
        case .date: 1
        case .weather: 2
        case .battery: 3
        }
    }
}

#Preview {
    SettingsView()
}
