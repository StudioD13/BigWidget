import Foundation
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import IOKit.ps
#endif

/// A one-off battery reading, shared by the app's live monitor and the widget timeline.
struct BatteryReading: Sendable, Codable {
    /// Charge level from 0 to 1, or `nil` when the device has no readable battery (e.g. a desktop Mac or Simulator).
    var level: Double?
    var isCharging = false

    @MainActor
    static func current() -> BatteryReading {
        #if canImport(UIKit)
        // Monitoring has to be on for `batteryLevel`/`batteryState` to report anything at all, but
        // switching it off again right after reading (as this used to do, to leave things as they
        // were found) made the next reading come back stale or stuck on an old state — including
        // showing "charging" well after the cable was actually pulled. Leaving it on for good, once
        // enabled, is the standard, reliable way to read it, and costs nothing a widget cares about.
        let device = UIDevice.current
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }

        return BatteryReading(
            level: device.batteryLevel >= 0 ? Double(device.batteryLevel) : nil,
            isCharging: device.batteryState == .charging || device.batteryState == .full
        )
        #elseif os(macOS)
        return macReading()
        #else
        return BatteryReading()
        #endif
    }

    #if os(macOS)
    private static func macReading() -> BatteryReading {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let max = description[kIOPSMaxCapacityKey] as? Int,
                max > 0
            else { continue }

            return BatteryReading(
                level: Double(current) / Double(max),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false
            )
        }
        return BatteryReading()
    }
    #endif
}
