import Foundation
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import IOKit.ps
#endif

/// A one-off battery reading, shared by the app's live monitor and the widget timeline.
struct BatteryReading: Sendable {
    /// Charge level from 0 to 1, or `nil` when the device has no readable battery (e.g. a desktop Mac or Simulator).
    var level: Double?
    var isCharging = false

    @MainActor
    static func current() -> BatteryReading {
        #if canImport(UIKit)
        let device = UIDevice.current
        let wasMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = wasMonitoring }

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
