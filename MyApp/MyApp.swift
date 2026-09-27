import SwiftUI

@main struct BigWidgetApp: App {
    var body: some Scene {
        WindowGroup("BigWidget") {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 360, minHeight: 360)
                // Translucent window: the desktop shows through behind the tiles.
                .containerBackground(.ultraThinMaterial, for: .window)
                #endif
        }
        #if os(visionOS)
        .defaultSize(width: 900, height: 700)
        #endif
    }
}
