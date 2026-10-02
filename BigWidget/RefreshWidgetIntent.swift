import AppIntents
import WidgetKit

/// Refreshes the BigWidget Home Screen widget right away — battery, charging status, and
/// everything else — without opening the app.
///
/// iOS gives a suspended widget extension no way to notice a hardware event like a charger being
/// plugged in; nothing short of a running process can react to that instantly. This intent is the
/// one mechanism iOS does offer for that: wired to a Personal Automation in Shortcuts for "Charger
/// Is Connected" / "Is Disconnected" (with "Ask Before Running" turned off), it runs silently the
/// moment the charger state changes and tells the widget to redraw with a fresh reading — the
/// closest thing to instant that's possible without Apple adding a background battery-change
/// callback for extensions. See BigWidget's README/help for the one-time Shortcuts setup.
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource { "Refresh BigWidget" }
    static var description: IntentDescription {
        IntentDescription("Updates the BigWidget widget right away, including its battery and charging status.")
    }

    /// No UI, and the app never opens or comes to the foreground — safe to run from an unattended
    /// automation.
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
