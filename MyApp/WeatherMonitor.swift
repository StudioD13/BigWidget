import Foundation
import CoreLocation
import Observation
import WeatherKit
import WidgetKit

/// Keeps the app's weather readout fresh and holds the Apple Weather attribution WeatherKit requires.
@Observable
final class WeatherMonitor {
    private(set) var reading: WeatherReading?
    private(set) var attribution: WeatherAttribution?
    /// True once a lookup has finished, so the UI can tell "loading" from "unavailable".
    private(set) var hasLoaded = false

    /// Refreshes every 15 minutes until the calling task is cancelled.
    func run() async {
        // Holding a service session asks for When In Use location permission (once) and keeps it active.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }

        attribution = try? await WeatherService.shared.attribution

        var isFirstLoad = true
        while !Task.isCancelled {
            reading = await WeatherReading.current()
            hasLoaded = true
            if isFirstLoad {
                // Permission may have just been granted; let widgets try again with location.
                WidgetCenter.shared.reloadAllTimelines()
                isFirstLoad = false
            }
            try? await Task.sleep(for: .seconds(15 * 60))
        }
    }
}
