import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#endif

@main struct BigWidgetApp: App {
    #if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    init() {
        SharedStore.moveReadoutSwitchesToAppGroup()
        #if os(iOS)
        // Registering has to happen before the task could possibly come due, so as early as
        // possible. Scheduling a request here too, not just on backgrounding, matters: registering
        // alone leaves nothing pending for iOS to actually run — confirmed the hard way, by trying
        // to trigger the task and having BackgroundTasks report none was scheduled.
        BatteryRefreshTask.register()
        BatteryRefreshTask.schedule()
        #endif
    }

    var body: some Scene {
        WindowGroup("BigWidget") {
            ContentView()
                // Always dark: neon reads best on black, and it keeps sheets and labels consistent.
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 360, minHeight: 360)
                .containerBackground(Color.black, for: .window)
                #endif
        }
        #if os(visionOS)
        .defaultSize(width: 900, height: 700)
        #endif
        #if os(macOS)
        // Opens tall and narrow, like the iPhone screen this is designed around, instead of
        // whatever arbitrary shape AppKit would otherwise pick — it's still a normal resizable
        // window from there, same as on iPad.
        .defaultSize(width: 420, height: 780)
        // The standard menu bar assumes a document-editing app: File > New Window would spawn a
        // second, fully independent dashboard (its own battery/weather polling, pointless here),
        // and Edit's Cut/Copy/Paste/Undo have nothing to act on in a display-only window. Both are
        // dead weight that doesn't exist on iOS; removing them is what makes this actually match it,
        // not just resemble it.
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .undoRedo) {}
        }
        #endif
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            // Whenever the app leaves the foreground is the standard, recommended time to leave a
            // background-refresh request behind for iOS to schedule.
            if newPhase == .background {
                BatteryRefreshTask.schedule()
                refreshWidgetsOnceInBackground()
            }
        }
        #endif
    }

    #if os(iOS)
    /// Fires the instant someone backgrounds BigWidget itself — e.g. pressing Home to look at the
    /// widget they just set this app up for — rather than waiting on iOS's own opportunistic
    /// background-refresh timing. `BatteryRefreshTask`/the widget's own reload-after policy still
    /// cover every other case (the app wasn't the thing in the foreground), where nothing short of
    /// that is possible for a third-party app.
    private func refreshWidgetsOnceInBackground() {
        var task: UIBackgroundTaskIdentifier = .invalid
        task = UIApplication.shared.beginBackgroundTask(withName: "ImmediateWidgetRefresh") {
            UIApplication.shared.endBackgroundTask(task)
            task = .invalid
        }
        guard task != .invalid else { return }
        Task {
            SharedStore.lastBattery = await BatteryReading.current()
            _ = await withTimeLimit(.seconds(8)) {
                await WeatherReading.current(locationTimeout: .seconds(5))
            }
            WidgetCenter.shared.reloadAllTimelines()
            UIApplication.shared.endBackgroundTask(task)
            task = .invalid
        }
    }
    #endif
}
