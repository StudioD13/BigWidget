import Foundation
import CoreLocation
import WeatherKit
import OSLog
import Synchronization

/// Current conditions, shared by the app and the widget.
///
/// MET Norway is tried first — global, free, no key — while its readings get evaluated against the
/// others (see `lookUp`). The National Weather Service comes next, in the U.S.: a real station's
/// measured reading, not a model's estimate. Apple Weather (WeatherKit), a modeled nowcast, is the
/// last resort, used only when neither free service has an answer.
struct WeatherReading: Sendable, Equatable, Codable {
    enum Source: String, Sendable, Equatable, Codable {
        case appleWeather, nationalWeatherService, metNorway
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
    /// The weather station the reading was measured at, when the source reports one
    /// (e.g. "Jackson, Hawkins Field Airport").
    var station: String?

    static let sample = WeatherReading(temperature: "72°", celsius: 22, condition: "Partly Cloudy", symbolName: "cloud.sun.fill")

    /// Why a lookup produced no weather, so the app can say something useful.
    enum Failure: Error, Sendable, Equatable {
        /// Location permission is off, or no fix arrived in time.
        case noLocation
        /// Neither weather service answered (e.g. no internet connection).
        case serviceUnavailable
    }

    /// Fetches current conditions for the device's location (or the last saved one) and saves the result
    /// to the App Group, so widgets can show it instantly.
    /// The first fix after launch can take 15 seconds or more, so the app waits up to 20.
    static func fetch(locationTimeout: Duration = .seconds(20)) async -> Result<WeatherReading, Failure> {
        let location: CLLocation
        if let fresh = await LocationFetcher.current(timeout: locationTimeout) {
            SharedStore.save(location: fresh)
            location = fresh
        } else if let saved = SharedStore.lastLocation {
            // Widgets often can't get a fresh fix; weather for the last known place is fine.
            location = saved
        } else {
            logger.notice("Weather skipped: no location available")
            return .failure(.noLocation)
        }

        let result = await lookUp(at: location)
        if case .success(let reading) = result {
            SharedStore.save(weather: reading)
        }
        return result
    }

    private static func lookUp(at location: CLLocation) async -> Result<WeatherReading, Failure> {
        // MET Norway first, for now — evaluating it as a possible global replacement for the
        // WeatherKit fallback. Still falls back the same way if it has nothing.
        do {
            let reading = try await MetNorwayWeatherService.current(at: location.coordinate)
            logger.notice("MET Norway loaded: \(reading.temperature, privacy: .public) \(reading.condition, privacy: .public)")
            return .success(reading)
        } catch {
            logger.notice("MET Norway unavailable, trying National Weather Service: \(String(describing: error), privacy: .public)")
        }
        do {
            let reading = try await NationalWeatherService.current(at: location.coordinate)
            logger.notice("National Weather Service loaded: \(reading.temperature, privacy: .public) \(reading.condition, privacy: .public) at \(reading.station ?? "forecast grid", privacy: .public)")
            return .success(reading)
        } catch {
            logger.notice("National Weather Service unavailable, trying Apple Weather: \(String(describing: error), privacy: .public)")
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
            logger.error("Apple Weather failed too: \(error.localizedDescription, privacy: .public)")
            return .failure(.serviceUnavailable)
        }
    }

    /// Current conditions, or `nil` if location or weather isn't available.
    static func current(locationTimeout: Duration = .seconds(20)) async -> WeatherReading? {
        try? await fetch(locationTimeout: locationTimeout).get()
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

/// Global weather source: MET Norway's Locationforecast API (api.met.no). Free, no key or account —
/// just a descriptive User-Agent — and licensed for commercial use (CC BY 4.0) under a fair-use
/// policy rather than a hard quota. Its forecast grid covers the whole world, not just Norway.
enum MetNorwayWeatherService {
    static let attributionURL = URL(string: "https://www.met.no/")!

    enum Failure: Error {
        case noData
    }

    /// MET Norway asks every client to identify itself with a descriptive User-Agent.
    private static let userAgent = "BigWidget/1.0 (Studio-D.BigWidget)"

    static func current(at coordinate: CLLocationCoordinate2D) async throws -> WeatherReading {
        let url = URL(string: String(
            format: "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=%.4f&lon=%.4f",
            coordinate.latitude, coordinate.longitude
        ))!
        let response = try await get(ForecastResponse.self, from: url)
        guard let entry = response.properties.timeseries.first,
              let celsius = entry.data.instant.details.airTemperature
        else { throw Failure.noData }

        let symbolCode = entry.data.next1Hours?.summary.symbolCode ?? "cloudy"
        let isDay = !symbolCode.hasSuffix("_night")
        return WeatherReading(
            temperature: WeatherReading.format(Measurement(value: celsius, unit: UnitTemperature.celsius)),
            celsius: celsius,
            condition: condition(for: symbolCode),
            symbolName: symbol(for: symbolCode, isDay: isDay),
            source: .metNorway
        )
    }

    /// A human-readable label for a symbol code like "lightrainshowers_day" or "heavyrainandthunder".
    private static func condition(for symbolCode: String) -> String {
        let base = symbolCode
            .replacingOccurrences(of: "_day", with: "")
            .replacingOccurrences(of: "_night", with: "")
            .replacingOccurrences(of: "_polartwilight", with: "")
        let known: [String: String] = [
            "clearsky": "Clear", "fair": "Fair", "partlycloudy": "Partly Cloudy", "cloudy": "Cloudy",
            "fog": "Fog", "rain": "Rain", "lightrain": "Light Rain", "heavyrain": "Heavy Rain",
            "rainshowers": "Rain Showers", "lightrainshowers": "Light Rain Showers",
            "heavyrainshowers": "Heavy Rain Showers",
            "sleet": "Sleet", "lightsleet": "Light Sleet", "heavysleet": "Heavy Sleet",
            "sleetshowers": "Sleet Showers", "lightsleetshowers": "Light Sleet Showers",
            "heavysleetshowers": "Heavy Sleet Showers",
            "snow": "Snow", "lightsnow": "Light Snow", "heavysnow": "Heavy Snow",
            "snowshowers": "Snow Showers", "lightsnowshowers": "Light Snow Showers",
            "heavysnowshowers": "Heavy Snow Showers",
            "rainandthunder": "Thunderstorms", "heavyrainandthunder": "Severe Thunderstorms",
            "rainshowersandthunder": "Thunderstorms", "sleetandthunder": "Thunderstorms",
            "snowandthunder": "Thunder Snow"
        ]
        if let label = known[base] { return label }
        if base.contains("thunder") { return "Thunderstorms" }
        return base.isEmpty ? "Weather" : base
    }

    /// An SF Symbol for a symbol code such as "lightrainshowers_day" or "partlycloudy_night".
    private static func symbol(for symbolCode: String, isDay: Bool) -> String {
        func has(_ words: String...) -> Bool { words.contains { symbolCode.contains($0) } }
        if has("thunder") { return "cloud.bolt.rain.fill" }
        if has("snow") { return "cloud.snow.fill" }
        if has("sleet") { return "cloud.sleet.fill" }
        if has("heavyrain") { return "cloud.heavyrain.fill" }
        if has("lightrain") { return "cloud.drizzle.fill" }
        if has("rain") { return "cloud.rain.fill" }
        if has("fog") { return "cloud.fog.fill" }
        if has("partlycloudy") { return isDay ? "cloud.sun.fill" : "cloud.moon.fill" }
        if has("cloudy") { return "cloud.fill" }
        if has("fair", "clearsky") { return isDay ? "sun.max.fill" : "moon.stars.fill" }
        return "cloud.fill"
    }

    // MARK: Networking

    private static func get<Response: Decodable>(_ type: Response.Type, from url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }

    private struct ForecastResponse: Decodable {
        struct Properties: Decodable {
            struct Entry: Decodable {
                struct EntryData: Decodable {
                    struct Instant: Decodable {
                        struct Details: Decodable {
                            var airTemperature: Double?
                            enum CodingKeys: String, CodingKey {
                                case airTemperature = "air_temperature"
                            }
                        }
                        var details: Details
                    }
                    struct NextHours: Decodable {
                        struct Summary: Decodable {
                            var symbolCode: String
                            enum CodingKeys: String, CodingKey {
                                case symbolCode = "symbol_code"
                            }
                        }
                        var summary: Summary
                    }
                    var instant: Instant
                    var next1Hours: NextHours?
                    enum CodingKeys: String, CodingKey {
                        case instant
                        case next1Hours = "next_1_hours"
                    }
                }
                var time: Date
                var data: EntryData
            }
            var timeseries: [Entry]
        }
        var properties: Properties
    }
}

/// Backup weather source: the U.S. National Weather Service (api.weather.gov). Free, no key or account,
/// and highly local — the latest measured reading from the nearest official weather station, falling
/// back to the 2.5 km gridpoint hourly forecast. Covers U.S. locations only. NWS data is public domain;
/// the app credits it anyway.
enum NationalWeatherService {
    static let attributionURL = URL(string: "https://www.weather.gov/")!

    enum Failure: Error {
        /// The location is outside NWS coverage (it only covers the U.S.).
        case outsideCoverage
        /// No nearby station had a recent temperature and there was no forecast to fall back on.
        case noData
    }

    /// NWS asks every client to identify itself with a User-Agent.
    private static let userAgent = "BigWidget/1.0 (Studio-D.BigWidget)"
    /// A station reading older than this is skipped in favor of the next-nearest station.
    private static let maxObservationAge: TimeInterval = 2 * 60 * 60
    /// How many of the nearest stations to try; some report without a temperature.
    private static let stationsToTry = 3

    static func current(at coordinate: CLLocationCoordinate2D) async throws -> WeatherReading {
        let point = try await point(at: coordinate)
        for station in point.stations.prefix(stationsToTry) {
            if let reading = try? await latestObservation(at: station) { return reading }
        }
        return try await hourlyForecast(point)
    }

    // MARK: Grid point and nearby stations

    /// The NWS grid cell for a place: its nearby stations (nearest first) and its hourly forecast.
    /// Saved in the App Group so repeat lookups take one request instead of three.
    private struct Point: Codable {
        struct Station: Codable {
            var id: String
            var name: String
        }
        /// Rounded to about 1 km, the area a saved point is reused for.
        var latitude: Double
        var longitude: Double
        var stations: [Station]
        var hourlyForecast: URL?
    }

    private static func point(at coordinate: CLLocationCoordinate2D) async throws -> Point {
        let latitude = (coordinate.latitude * 100).rounded() / 100
        let longitude = (coordinate.longitude * 100).rounded() / 100
        if let data = SharedStore.defaults.data(forKey: SharedStore.Key.weatherServicePoint),
           let saved = try? JSONDecoder().decode(Point.self, from: data),
           saved.latitude == latitude, saved.longitude == longitude, !saved.stations.isEmpty {
            return saved
        }

        let url = URL(string: String(format: "https://api.weather.gov/points/%.4f,%.4f", coordinate.latitude, coordinate.longitude))!
        let grid = try await get(PointResponse.self, from: url).properties
        var point = Point(latitude: latitude, longitude: longitude, stations: [], hourlyForecast: grid.forecastHourly)
        if let stationsURL = grid.observationStations {
            point.stations = try await get(StationsResponse.self, from: stationsURL).features.map {
                Point.Station(id: $0.properties.stationIdentifier, name: $0.properties.name)
            }
        }
        if let data = try? JSONEncoder().encode(point) {
            SharedStore.defaults.set(data, forKey: SharedStore.Key.weatherServicePoint)
        }
        return point
    }

    // MARK: Readings

    /// The station's latest measured conditions.
    private static func latestObservation(at station: Point.Station) async throws -> WeatherReading {
        let url = URL(string: "https://api.weather.gov/stations/\(station.id)/observations/latest")!
        let observation = try await get(ObservationResponse.self, from: url).properties
        guard let celsius = observation.temperature.value,
              Date.now.timeIntervalSince(observation.timestamp) < maxObservationAge
        else { throw Failure.noData }

        let condition = observation.textDescription.flatMap { $0.isEmpty ? nil : $0 } ?? "Weather"
        let isDay = observation.icon?.contains("/night/") != true
        return WeatherReading(
            temperature: WeatherReading.format(Measurement(value: celsius, unit: UnitTemperature.celsius)),
            celsius: celsius,
            condition: condition,
            symbolName: symbol(for: condition, isDay: isDay),
            source: .nationalWeatherService,
            station: station.name
        )
    }

    /// The current hour's forecast for the 2.5 km grid cell, used when no nearby station has a recent reading.
    private static func hourlyForecast(_ point: Point) async throws -> WeatherReading {
        guard let url = point.hourlyForecast,
              let period = try await get(ForecastResponse.self, from: url).properties.periods.first
        else { throw Failure.noData }

        let unit: UnitTemperature = period.temperatureUnit == "C" ? .celsius : .fahrenheit
        let temperature = Measurement(value: period.temperature, unit: unit)
        return WeatherReading(
            temperature: WeatherReading.format(temperature),
            celsius: temperature.converted(to: .celsius).value,
            condition: period.shortForecast,
            symbolName: symbol(for: period.shortForecast, isDay: period.isDaytime),
            source: .nationalWeatherService
        )
    }

    /// An SF Symbol for an NWS description such as "Light Rain and Fog/Mist" or "Mostly Cloudy".
    private static func symbol(for description: String, isDay: Bool) -> String {
        let text = description.lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }
        if has("thunder") { return "cloud.bolt.rain.fill" }
        if has("snow", "flurr", "blizzard") { return "cloud.snow.fill" }
        if has("sleet", "freezing", "ice pellets", "hail") { return "cloud.sleet.fill" }
        if has("heavy rain") { return "cloud.heavyrain.fill" }
        if has("drizzle") { return "cloud.drizzle.fill" }
        if has("rain", "shower") { return "cloud.rain.fill" }
        if has("fog", "mist", "haze", "smoke", "dust") { return "cloud.fog.fill" }
        if has("partly", "few clouds", "mostly sunny", "mostly clear") { return isDay ? "cloud.sun.fill" : "cloud.moon.fill" }
        if has("cloud", "overcast") { return "cloud.fill" }
        if has("wind", "breez") { return "wind" }
        if has("sun", "clear", "fair") { return isDay ? "sun.max.fill" : "moon.stars.fill" }
        return "cloud.fill"
    }

    // MARK: Networking

    private static func get<Response: Decodable>(_ type: Response.Type, from url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: break
        case 404: throw Failure.outsideCoverage
        default: throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }

    private struct PointResponse: Decodable {
        struct Properties: Decodable {
            var observationStations: URL?
            var forecastHourly: URL?
        }
        var properties: Properties
    }

    private struct StationsResponse: Decodable {
        struct Feature: Decodable {
            struct Properties: Decodable {
                var stationIdentifier: String
                var name: String
            }
            var properties: Properties
        }
        var features: [Feature]
    }

    private struct ObservationResponse: Decodable {
        struct Properties: Decodable {
            struct Value: Decodable {
                var value: Double?
            }
            var timestamp: Date
            var textDescription: String?
            var icon: String?
            var temperature: Value
        }
        var properties: Properties
    }

    private struct ForecastResponse: Decodable {
        struct Properties: Decodable {
            struct Period: Decodable {
                var temperature: Double
                var temperatureUnit: String
                var shortForecast: String
                var isDaytime: Bool
            }
            var periods: [Period]
        }
        var properties: Properties
    }
}

/// A one-off location lookup that works in both the app and the widget extension.
enum LocationFetcher {
    private static let logger = Logger(subsystem: "Studio-D.BigWidget", category: "Location")

    static func current(timeout: Duration = .seconds(20)) async -> CLLocation? {
        // A cached fix from the last few hours is plenty for weather and avoids waiting on the GPS.
        if let cached = CLLocationManager().location, cached.timestamp > Date.now.addingTimeInterval(-3 * 3600) {
            return cached
        }
        // Raced against the timeout without waiting for the lookup to wind down: without permission
        // (as in a widget) the updates can stall, and a task group would wait for them forever.
        return await withTimeLimit(timeout) {
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
    }
}

/// Runs `operation`, but returns `nil` once `limit` passes without waiting for it to finish.
/// (A task group would still wait for a child that ignores cancellation, as WeatherKit and
/// location updates can.)
func withTimeLimit<T: Sendable>(
    _ limit: Duration, _ operation: @escaping @Sendable () async -> T?
) async -> T? {
    await withCheckedContinuation { continuation in
        let first = FirstResult<T?>(continuation)
        let work = Task { first.resume(await operation()) }
        Task {
            try? await Task.sleep(for: limit)
            work.cancel()
            first.resume(nil)
        }
    }
}

/// Resumes a continuation exactly once, with whichever result arrives first.
private final class FirstResult<T: Sendable>: Sendable {
    private let continuation: Mutex<CheckedContinuation<T, Never>?>

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = Mutex(continuation)
    }

    func resume(_ value: T) {
        continuation.withLock { $0.take() }?.resume(returning: value)
    }
}
