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
        static let effect = "neonEffect"
        static let speed = "neonSpeed"
        static let numbers = "numberStyle"
        static let bloom = "neonBloom"
        static let latitude = "lastLatitude"
        static let longitude = "lastLongitude"
        static let locationDate = "lastLocationDate"
        static let weather = "lastWeather"
        static let weatherDate = "lastWeatherDate"
    }

    // MARK: Style

    /// The neon style chosen in the app. Widgets set to "Match App" use this.
    static var appStyle: NeonStyle {
        NeonStyle(
            scheme: defaults.string(forKey: Key.scheme).flatMap(NeonScheme.init(rawValue:)) ?? .classic,
            effect: defaults.string(forKey: Key.effect).flatMap(NeonEffect.init(rawValue:)) ?? .coursing,
            speed: defaults.string(forKey: Key.speed).flatMap(NeonSpeed.init(rawValue:)) ?? .normal,
            numbers: defaults.string(forKey: Key.numbers).flatMap(NumberStyle.init(rawValue:)) ?? .neon,
            bloom: defaults.string(forKey: Key.bloom).flatMap(NeonBloom.init(rawValue:)) ?? .soft
        )
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
}
