import Foundation
import Observation

/// Keeps the app's battery readout fresh on iOS, visionOS, and macOS.
@Observable
final class BatteryMonitor {
    /// Charge level from 0 to 1, or `nil` when the device has no readable battery (e.g. a desktop Mac or Simulator).
    private(set) var level: Double?
    private(set) var isCharging = false

    /// Refreshes the reading periodically until the calling task is cancelled.
    func run() async {
        while !Task.isCancelled {
            let reading = BatteryReading.current()
            level = reading.level
            isCharging = reading.isCharging
            try? await Task.sleep(for: .seconds(20))
        }
    }
}
