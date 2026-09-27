import WidgetKit
import AppIntents

/// Lets people pick which readouts a BigWidget shows: any one, any two, or all three.
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Readouts" }
    static var description: IntentDescription { "Pick which big readouts this widget shows." }

    @Parameter(title: "Time", default: true)
    var showTime: Bool

    @Parameter(title: "Date", default: true)
    var showDate: Bool

    @Parameter(title: "Battery", default: false)
    var showBattery: Bool

    init() {}

    init(time: Bool, date: Bool, battery: Bool) {
        showTime = time
        showDate = date
        showBattery = battery
    }

    /// The readouts to show, in display order. Falls back to Time if everything is switched off.
    var readouts: [Readout] {
        var result: [Readout] = []
        if showTime { result.append(.time) }
        if showDate { result.append(.date) }
        if showBattery { result.append(.battery) }
        return result.isEmpty ? [.time] : result
    }
}

enum Readout: Hashable {
    case time, date, battery
}
