import Foundation
import CoreLocation
import Observation
import WeatherKit
import WidgetKit

/// Keeps the app's weather readout fresh and holds the Apple Weather attribution WeatherKit requires.
@Observable
final class WeatherMonitor {
    private(set) var reading: WeatherReading?
    private(set) var failure: WeatherReading.Failure?
    private(set) var attribution: WeatherAttribution?
    /// True once a lookup has finished, so the UI can tell "loading" from "unavailable".
    private(set) var hasLoaded = false

    /// A short explanation to show while there's no reading.
    var statusText: String {
        guard hasLoaded else { return "Loading Weather…" }
        switch failure {
        case .noLocation: return "Location Off"
        case .serviceUnavailable: return "Waiting for Apple Weather…"
        case nil: return "Weather Unavailable"
        }
    }

    /// Refreshes every 15 minutes, retrying every minute while weather is unavailable,
    /// until the calling task is cancelled.
    func run() async {
        // Holding a service session asks for When In Use location permission (once) and keeps it active.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }

        var hadWeather = false
        while !Task.isCancelled {
            switch await WeatherReading.fetch() {
            case .success(let newReading):
                reading = newReading
                failure = nil
                if !hadWeather {
                    // First success (e.g. WeatherKit just activated): let widgets refresh too.
                    WidgetCenter.shared.reloadAllTimelines()
                    hadWeather = true
                }
            case .failure(let newFailure):
                failure = newFailure
            }
            hasLoaded = true

            if attribution == nil {
                attribution = try? await WeatherService.shared.attribution
            }
            try? await Task.sleep(for: .seconds(reading == nil ? 60 : 15 * 60))
        }
    }
}
