import SwiftUI

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
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            // Whenever the app leaves the foreground is the standard, recommended time to leave a
            // background-refresh request behind for iOS to schedule.
            if newPhase == .background {
                BatteryRefreshTask.schedule()
            }
        }
        #endif
    }
}
