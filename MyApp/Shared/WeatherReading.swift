import Foundation
import CoreLocation
import WeatherKit
import OSLog

/// Current conditions, shared by the app and the widget.
///
/// Apple Weather (WeatherKit) is tried first. If it refuses — most often because Apple hasn't finished
/// activating WeatherKit for a new app ID — the same reading comes from Open-Meteo, a free service that
/// needs no key or account. Apple Weather takes over automatically as soon as it starts answering.
struct WeatherReading: Sendable, Equatable {
    enum Source: Sendable, Equatable {
        case appleWeather, openMeteo
    }

    /// Rounded, in the person's preferred unit, e.g. "72°".
    var temperature: String
    /// Used to color the Classic scheme.
    var celsius: Double
    /// Description, e.g. "Partly Cloudy".
    var condition: String
    /// SF Symbol for the conditions.
    var symbolName: String
    /// Where the data came from, so the right attribution is shown.
    var source: Source = .appleWeather

    static let sample = WeatherReading(temperature: "72°", celsius: 22, condition: "Partly Cloudy", symbolName: "cloud.sun.fill")

    /// Why a lookup produced no weather, so the app can say something useful.
    enum Failure: Error, Sendable, Equatable {
        /// Location permission is off, or no fix arrived in time.
        case noLocation
        /// Neither weather service answered (e.g. no internet connection).
        case serviceUnavailable
    }

    /// Fetches current conditions for the device's location.
    static func fetch() async -> Result<WeatherReading, Failure> {
        guard let location = await LocationFetcher.current() else {
            logger.notice("Weather skipped: no location available")
            return .failure(.noLocation)
        }
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            logger.notice("Apple Weather loaded: \(current.temperature.formatted(), privacy: .public)")
            return .success(WeatherReading(
                temperature: format(current.temperature),
                celsius: current.temperature.converted(to: .celsius).value,
                condition: current.condition.description,
                symbolName: current.symbolName,
                source: .appleWeather
            ))
        } catch {
            logger.error("Apple Weather failed, trying Open-Meteo: \(error.localizedDescription, privacy: .public)")
        }
        do {
            let reading = try await OpenMeteo.current(at: location.coordinate)
            logger.notice("Open-Meteo loaded: \(reading.temperature, privacy: .public)")
            return .success(reading)
        } catch {
            logger.error("Open-Meteo failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.serviceUnavailable)
        }
    }

    /// Current conditions, or `nil` if location or weather isn't available.
    static func current() async -> WeatherReading? {
        try? await fetch().get()
    }

    private static let logger = Logger(subsystem: "Studio-D.BigWidget", category: "Weather")

    /// Formats in the locale's weather unit, then keeps only what the neon glyphs can draw ("-72°").
    static func format(_ temperature: Measurement<UnitTemperature>) -> String {
        let text = temperature.formatted(
            .measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))
        )
        let digits = text
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .filter { $0.isASCII && ($0.isNumber || $0 == "-") }
        return digits + "°"
    }
}

/// Backup weather source: Open-Meteo's free forecast API (no key required).
/// Its data is licensed CC BY 4.0, so the app credits "Weather data by Open-Meteo.com" when it's used.
enum OpenMeteo {
    static let attributionURL = URL(string: "https://open-meteo.com/")!

    private struct Response: Decodable {
        struct Current: Decodable {
            var temperature_2m: Double
            var weather_code: Int
            var is_day: Int
        }
        var current: Current
    }

    static func current(at coordinate: CLLocationCoordinate2D) async throws -> WeatherReading {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let current = try JSONDecoder().decode(Response.self, from: data).current
        let (condition, symbol) = describe(code: current.weather_code, isDay: current.is_day == 1)
        let temperature = Measurement(value: current.temperature_2m, unit: UnitTemperature.celsius)
        return WeatherReading(
            temperature: WeatherReading.format(temperature),
            celsius: current.temperature_2m,
            condition: condition,
            symbolName: symbol,
            source: .openMeteo
        )
    }

    /// Maps WMO weather codes (used by Open-Meteo) to a description and SF Symbol.
    private static func describe(code: Int, isDay: Bool) -> (String, String) {
        switch code {
        case 0: ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1: ("Mostly Clear", isDay ? "sun.max.fill" : "moon.fill")
        case 2: ("Partly Cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: ("Cloudy", "cloud.fill")
        case 45, 48: ("Foggy", "cloud.fog.fill")
        case 51, 53, 55: ("Drizzle", "cloud.drizzle.fill")
        case 56, 57, 66, 67: ("Freezing Rain", "cloud.sleet.fill")
        case 61, 63, 80, 81: ("Rain", "cloud.rain.fill")
        case 65, 82: ("Heavy Rain", "cloud.heavyrain.fill")
        case 71, 73, 77, 85: ("Snow", "cloud.snow.fill")
        case 75, 86: ("Heavy Snow", "cloud.snow.fill")
        case 95: ("Thunderstorms", "cloud.bolt.rain.fill")
        case 96, 99: ("Thunderstorms and Hail", "cloud.bolt.rain.fill")
        default: ("Weather", "cloud.fill")
        }
    }
}

/// A one-off location lookup that works in both the app and the widget extension.
enum LocationFetcher {
    private static let logger = Logger(subsystem: "Studio-D.BigWidget", category: "Location")

    static func current(timeout: Duration = .seconds(8)) async -> CLLocation? {
        // A recent cached fix is plenty for weather and avoids waking the GPS.
        if let cached = CLLocationManager().location, cached.timestamp > Date.now.addingTimeInterval(-3600) {
            return cached
        }
        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location { return location }
                        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                            logger.notice("Location unavailable: not authorized")
                            return nil
                        }
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
