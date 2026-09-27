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
        case .serviceUnavailable: return "No Weather Connection"
        case nil: return "Weather Unavailable"
        }
    }

    /// Refreshes every 15 minutes, retrying every minute while weather is unavailable,
    /// until the calling task is cancelled.
    func run() async {
        #if os(macOS)
        // macOS has no CLServiceSession; ask through a location manager kept alive for the loop.
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        defer { withExtendedLifetime(manager) {} }
        #else
        // Holding a service session asks for When In Use location permission (once) and keeps it active.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        #endif

        while !Task.isCancelled {
            switch await WeatherReading.fetch() {
            case .success(let newReading):
                if newReading != reading {
                    // The reading is saved to the App Group; refresh widgets so they show it now.
                    // (Reloads requested by the foreground app don't use the widgets' daily budget.)
                    WidgetCenter.shared.reloadAllTimelines()
                }
                reading = newReading
                failure = nil
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
