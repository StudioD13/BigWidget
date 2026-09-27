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

    /// On: use the colors, effect, and speed chosen in the BigWidget app (changes apply instantly).
    @Parameter(title: "Match App Style", default: true)
    var matchAppStyle: Bool

    @Parameter(title: "Colors", default: .classic)
    var scheme: NeonScheme

    @Parameter(title: "Effect", default: .coursing)
    var effect: NeonEffect

    @Parameter(title: "Speed", default: .normal)
    var speed: NeonSpeed

    static var parameterSummary: some ParameterSummary {
        When(\.$matchAppStyle, .equalTo, true) {
            Summary {
                \.$showTime
                \.$showDate
                \.$showBattery
                \.$showWeather
                \.$matchAppStyle
            }
        } otherwise: {
            Summary {
                \.$showTime
                \.$showDate
                \.$showBattery
                \.$showWeather
                \.$matchAppStyle
                \.$scheme
                \.$effect
                \.$speed
            }
        }
    }

    init() {}

    init(
        time: Bool, date: Bool, battery: Bool, weather: Bool = false,
        style: NeonStyle? = nil
    ) {
        showTime = time
        showDate = date
        showBattery = battery
        showWeather = weather
        matchAppStyle = style == nil
        scheme = style?.scheme ?? .classic
        effect = style?.effect ?? .coursing
        speed = style?.speed ?? .normal
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

    /// The style to draw with: the app's (from the shared App Group) or this widget's own.
    var style: NeonStyle {
        matchAppStyle ? SharedStore.appStyle : NeonStyle(scheme: scheme, effect: effect, speed: speed)
    }
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

extension NeonSpeed: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Speed" }
    static var caseDisplayRepresentations: [NeonSpeed: DisplayRepresentation] {
        [
            .slow: "Slow",
            .normal: "Normal",
            .fast: "Fast",
            .turbo: "Turbo"
        ]
    }
}
