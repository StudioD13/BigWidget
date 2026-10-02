import Foundation
#if os(iOS)
import BackgroundTasks
import WidgetKit
import OSLog

/// Periodically wakes the app in the background to check the battery and nudge the Home Screen
/// widget if the charge level or charging status has actually changed.
///
/// This is what closes the gap the Shortcuts-automation route left open: that route is genuinely
/// near-instant, but only works if someone sets it up by hand. This one needs no setup at all —
/// just installing and opening the app once, which every app requires anyway — because `BGTaskScheduler`
/// registration has to happen while the app's own code runs at least once. iOS still won't say
/// exactly when it'll run this (it schedules background wake-ups opportunistically, based on
/// battery, usage patterns, and its own judgment, typically every 15–30 minutes for an app in
/// regular use) — no third-party app can get a true instant push for a hardware event like a
/// charger being plugged in, on or off this mechanism. But this runs without the person ever
/// having to think about it, which the Shortcuts route doesn't.
enum BatteryRefreshTask {
    static let identifier = "Studio-D.BigWidget.refresh"

    /// The soonest to ask for the next wake-up. A floor, not a guarantee — see above.
    private static let interval: TimeInterval = 15 * 60

    private static let logger = Logger(subsystem: "Studio-D.BigWidget", category: "BatteryRefresh")

    /// Call once, early at launch (before the task could possibly come due).
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handle(task)
        }
    }

    /// Leaves a pending request behind so iOS has something to schedule. Call at launch and again
    /// whenever the app leaves the foreground — a fulfilled or expired request doesn't resubmit
    /// itself.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        logger.notice("Background refresh fired")
        // Leave the next request behind immediately, so one run (success, failure, or cut off by
        // the system) doesn't end the chain.
        schedule()

        let work = Task {
            let before = SharedStore.lastBattery
            let reading = await BatteryReading.current()
            SharedStore.lastBattery = reading
            let changed = reading.level != before?.level || reading.isCharging != before?.isCharging
            logger.notice("""
                Read battery: level=\(reading.level ?? -1, privacy: .public) \
                isCharging=\(reading.isCharging, privacy: .public) changed=\(changed, privacy: .public)
                """)
            if changed {
                WidgetCenter.shared.reloadAllTimelines()
            }
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
}
#endif
