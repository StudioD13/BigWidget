import SwiftUI
import WidgetKit

/// App preferences. The neon style is stored in the shared App Group, so widgets set to
/// "Match App Style" pick up changes immediately.
struct SettingsView: View {
    @AppStorage(SharedStore.Key.scheme, store: SharedStore.defaults) private var scheme: NeonScheme = .classic
    @AppStorage(SharedStore.Key.effect, store: SharedStore.defaults) private var effect: NeonEffect = .coursing
    @AppStorage(SharedStore.Key.speed, store: SharedStore.defaults) private var speed: NeonSpeed = .normal

    @AppStorage(AppTile.time.storageKey) private var showTime = true
    @AppStorage(AppTile.date.storageKey) private var showDate = true
    @AppStorage(AppTile.weather.storageKey) private var showWeather = true
    @AppStorage(AppTile.battery.storageKey) private var showBattery = true

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
                    Text("Show in App")
                } footer: {
                    Text("Each widget chooses its own readouts: touch and hold a widget, then choose Edit Widget.")
                }

                Section {
                    Picker("Colors", selection: $scheme) {
                        ForEach(NeonScheme.allCases, id: \.self) { Text($0.title) }
                    }
                    Picker("Effect", selection: $effect) {
                        ForEach(NeonEffect.allCases, id: \.self) { Text($0.title) }
                    }
                    Picker("Speed", selection: $speed) {
                        ForEach(NeonSpeed.allCases, id: \.self) { Text($0.title) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Neon")
                } footer: {
                    Text("Widgets with Match App Style turned on use these too. Widgets can only move once a minute; the app moves continuously.")
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
        .onChange(of: scheme) { reloadWidgets() }
        .onChange(of: effect) { reloadWidgets() }
        .onChange(of: speed) { reloadWidgets() }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// The tiles the app can show, in display order.
enum AppTile: String, CaseIterable, Identifiable {
    case time, date, weather, battery

    var id: Self { self }
    var storageKey: String { "showTile.\(rawValue)" }
}

#Preview {
    SettingsView()
}
