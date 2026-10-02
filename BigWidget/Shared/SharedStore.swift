import Foundation
import CoreLocation

/// Settings and readings shared between the app and its widgets through an App Group.
///
/// The app writes here; widgets read instantly instead of waiting on slow lookups
/// (location, network) every time WidgetKit asks for a timeline.
enum SharedStore {
    static let appGroup = "group.Studio-D.BigWidget"

    /// Shared defaults, falling back to standard defaults if the App Group isn't provisioned.
    static let defaults: UserDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    enum Key {
        static let scheme = "neonScheme"
        static let numbers = "numberStyle"
        static let bloom = "neonBloom"
        static let thickness = "numberThickness"
        static let isRandom = "isRandomStyle"
        static let latitude = "lastLatitude"
        static let longitude = "lastLongitude"
        static let locationDate = "lastLocationDate"
        static let weather = "lastWeather"
        static let weatherDate = "lastWeatherDate"
        static let weatherServicePoint = "weatherServicePoint"
        static let lastBattery = "lastBatteryReading"
    }

    // MARK: Style

    /// The neon style chosen in the app. Widgets set to "Match App" use this.
    static var appStyle: NeonStyle {
        NeonStyle(
            scheme: defaults.string(forKey: Key.scheme).flatMap(NeonScheme.init(rawValue:)) ?? .classic,
            numbers: defaults.string(forKey: Key.numbers).flatMap(NumberStyle.init(rawValue:)) ?? .normal,
            bloom: defaults.string(forKey: Key.bloom).flatMap(NeonBloom.init(rawValue:)) ?? .soft,
            thickness: defaults.string(forKey: Key.thickness).flatMap(NumberThickness.init(rawValue:)) ?? .regular
        )
    }

    /// Whether the app's Random option is on. A "Match App" widget checks this so it can keep
    /// randomizing its look once a minute on its own, without needing the app to be running.
    static var isRandom: Bool {
        defaults.bool(forKey: Key.isRandom)
    }

    // MARK: Readouts

    /// Whether the app shows a readout ("time", "date", "weather", or "battery"). Widgets set to
    /// Match App show the same ones. Everything is shown until it's switched off.
    static func showsInApp(_ readout: String) -> Bool {
        defaults.object(forKey: showKey(readout)) as? Bool ?? true
    }

    static func showKey(_ readout: String) -> String { "showTile.\(readout)" }

    /// The app used to keep its readout switches in its own defaults, where widgets can't see them.
    /// Copies any saved there into the App Group, once.
    static func moveReadoutSwitchesToAppGroup() {
        guard defaults !== UserDefaults.standard else { return }
        for readout in ["time", "date", "weather", "battery"] {
            let key = showKey(readout)
            if defaults.object(forKey: key) == nil, let value = UserDefaults.standard.object(forKey: key) as? Bool {
                defaults.set(value, forKey: key)
            }
        }
    }

    // MARK: Location

    static func save(location: CLLocation) {
        defaults.set(location.coordinate.latitude, forKey: Key.latitude)
        defaults.set(location.coordinate.longitude, forKey: Key.longitude)
        defaults.set(location.timestamp, forKey: Key.locationDate)
    }

    /// The last location the app or widget saw, if any.
    static var lastLocation: CLLocation? {
        guard defaults.object(forKey: Key.latitude) != nil,
              let date = defaults.object(forKey: Key.locationDate) as? Date
        else { return nil }
        return CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: defaults.double(forKey: Key.latitude),
                longitude: defaults.double(forKey: Key.longitude)
            ),
            altitude: 0, horizontalAccuracy: 100, verticalAccuracy: -1, timestamp: date
        )
    }

    // MARK: Weather

    static func save(weather: WeatherReading) {
        guard let data = try? JSONEncoder().encode(weather) else { return }
        defaults.set(data, forKey: Key.weather)
        defaults.set(Date.now, forKey: Key.weatherDate)
    }

    /// The last weather reading and when it was fetched.
    static var cachedWeather: (reading: WeatherReading, date: Date)? {
        guard let data = defaults.data(forKey: Key.weather),
              let date = defaults.object(forKey: Key.weatherDate) as? Date,
              let reading = try? JSONDecoder().decode(WeatherReading.self, from: data)
        else { return nil }
        return (reading, date)
    }

    // MARK: Battery

    /// The most recent battery reading anything has recorded, so a background refresh can tell
    /// whether the charge level or charging status actually changed before bothering to reload
    /// widgets.
    static var lastBattery: BatteryReading? {
        get {
            guard let data = defaults.data(forKey: Key.lastBattery) else { return nil }
            return try? JSONDecoder().decode(BatteryReading.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Key.lastBattery)
                return
            }
            defaults.set(data, forKey: Key.lastBattery)
        }
    }
}
