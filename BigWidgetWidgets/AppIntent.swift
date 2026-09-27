import WidgetKit
import AppIntents

/// Lets people pick which readouts a BigWidget shows (any combination) and how the neon looks.
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Readouts" }
    static var description: IntentDescription { "Pick which big readouts this widget shows and how the neon looks." }

    @Parameter(title: "Time", default: true)
    var showTime: Bool

    @Parameter(title: "Date", default: true)
    var showDate: Bool

    @Parameter(title: "Battery", default: false)
    var showBattery: Bool

    @Parameter(title: "Weather", default: false)
    var showWeather: Bool

    @Parameter(title: "Colors", default: .classic)
    var scheme: NeonScheme

    @Parameter(title: "Effect", default: .coursing)
    var effect: NeonEffect

    init() {}

    init(
        time: Bool, date: Bool, battery: Bool, weather: Bool = false,
        scheme: NeonScheme = .classic, effect: NeonEffect = .coursing
    ) {
        showTime = time
        showDate = date
        showBattery = battery
        showWeather = weather
        self.scheme = scheme
        self.effect = effect
    }

    /// The readouts to show, in display order. Falls back to Time if everything is switched off.
    var readouts: [Readout] {
        var result: [Readout] = []
        if showTime { result.append(.time) }
        if showDate { result.append(.date) }
        if showBattery { result.append(.battery) }
        if showWeather { result.append(.weather) }
        return result.isEmpty ? [.time] : result
    }

    var style: NeonStyle { NeonStyle(scheme: scheme, effect: effect) }
}

enum Readout: Hashable {
    case time, date, battery, weather
}

// Raw values are saved in people's widget configurations, so never rename existing cases.
extension NeonScheme: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Colors" }
    static var caseDisplayRepresentations: [NeonScheme: DisplayRepresentation] {
        [
            .classic: "Classic",
            .rainbow: "Rainbow",
            .red: "Red",
            .orange: "Orange",
            .yellow: "Yellow",
            .green: "Green",
            .blue: "Blue",
            .purple: "Purple",
            .white: "White"
        ]
    }
}

extension NeonEffect: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Effect" }
    static var caseDisplayRepresentations: [NeonEffect: DisplayRepresentation] {
        [
            .coursing: "Coursing",
            .sparkle: "Sparkle",
            .spectrum: "Spectrum",
            .breathe: "Breathe",
            .flicker: "Flicker",
            .steady: "Steady"
        ]
    }
}
