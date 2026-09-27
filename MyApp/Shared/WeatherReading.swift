import Foundation
import CoreLocation
import WeatherKit
import OSLog

/// Current conditions from WeatherKit, shared by the app and the widget.
struct WeatherReading: Sendable, Equatable {
    /// Rounded, in the person's preferred unit, e.g. "72°".
    var temperature: String
    /// Used to color the Classic scheme.
    var celsius: Double
    /// Localized description, e.g. "Partly Cloudy".
    var condition: String
    /// SF Symbol for the conditions.
    var symbolName: String

    static let sample = WeatherReading(temperature: "72°", celsius: 22, condition: "Partly Cloudy", symbolName: "cloud.sun.fill")

    /// Fetches current conditions for the device's location, or `nil` if location or weather isn't available.
    static func current() async -> WeatherReading? {
        guard let location = await LocationFetcher.current() else {
            logger.notice("Weather skipped: no location available")
            return nil
        }
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            logger.info("Weather loaded: \(current.temperature.formatted(), privacy: .public)")
            return WeatherReading(
                temperature: format(current.temperature),
                celsius: current.temperature.converted(to: .celsius).value,
                condition: current.condition.description,
                symbolName: current.symbolName
            )
        } catch {
            logger.error("Weather request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
