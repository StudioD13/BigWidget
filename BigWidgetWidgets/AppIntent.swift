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

    @Parameter(title: "Weather", default: true)
    var showWeather: Bool

    /// On: show the readouts and look chosen in the BigWidget app (changes apply instantly).
    /// (Named for when it covered only the look; the name is saved in people's widgets.)
    @Parameter(title: "Match App", default: false)
    var matchAppStyle: Bool

    /// On: a new random combination of Numbers, Colors, Bloom, and Thickness every minute,
    /// same as the app's own Random option.
    @Parameter(title: "Random", default: false)
    var isRandom: Bool

    @Parameter(title: "Numbers", default: .normal)
    var numbers: NumberStyle

    @Parameter(title: "Colors", default: .white)
    var scheme: NeonScheme

    @Parameter(title: "Bloom", default: .soft)
    var bloom: NeonBloom

    @Parameter(title: "Thickness", default: .regular)
    var thickness: NumberThickness

    static var parameterSummary: some ParameterSummary {
        When(\.$matchAppStyle, .equalTo, true) {
            // Everything comes from the app, so there's nothing else to choose.
            Summary {
                \.$matchAppStyle
            }
        } otherwise: {
            When(\.$isRandom, .equalTo, true) {
                // While Random is on, there's no fixed look to choose.
                Summary {
                    \.$showTime
                    \.$showDate
                    \.$showBattery
                    \.$showWeather
                    \.$matchAppStyle
                    \.$isRandom
                }
            } otherwise: {
                // Chalk doesn't glow, so Bloom is hidden for it.
                When(\.$numbers, .equalTo, .chalk) {
                    Summary {
                        \.$showTime
                        \.$showDate
                        \.$showBattery
                        \.$showWeather
                        \.$matchAppStyle
                        \.$isRandom
                        \.$numbers
                        \.$thickness
                        \.$scheme
                    }
                } otherwise: {
                    Summary {
                        \.$showTime
                        \.$showDate
                        \.$showBattery
                        \.$showWeather
                        \.$matchAppStyle
                        \.$isRandom
                        \.$numbers
                        \.$thickness
                        \.$scheme
                        \.$bloom
                    }
                }
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
        isRandom = false
        scheme = style?.scheme ?? .white
        numbers = style?.numbers ?? .normal
        bloom = style?.bloom ?? .soft
        thickness = style?.thickness ?? .regular
    }

    /// The readouts to show, in display order: the app's (from the shared App Group) or this widget's own.
    /// Falls back to Time if everything is switched off.
    var readouts: [Readout] {
        let shown: [(Readout, Bool)] = matchAppStyle
            ? Readout.allCases.map { ($0, SharedStore.showsInApp($0.rawValue)) }
            : [(.time, showTime), (.date, showDate), (.battery, showBattery), (.weather, showWeather)]
        let result = shown.filter(\.1).map(\.0)
        return result.isEmpty ? [.time] : result
    }

    /// The style to draw `readout` with: the app's (from the shared App Group) or this widget's
    /// own, each falling back to a fresh, independent random combination when Random is on — rolled
    /// separately for every readout and every widget instance, so none of them match each other.
    func style(for readout: Readout) -> NeonStyle {
        if matchAppStyle {
            return SharedStore.isRandom ? .random() : SharedStore.appStyle
        }
        return isRandom
            ? .random()
            : NeonStyle(scheme: scheme, numbers: numbers, bloom: bloom, thickness: thickness)
    }
}

/// Raw values match the app's readout switches in the App Group (see `SharedStore.showsInApp`).
enum Readout: String, Hashable, Codable, CaseIterable {
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
            .white: "White",
            .pink: "Pink",
            .teal: "Teal",
            .cyan: "Cyan",
            .mint: "Mint",
            .indigo: "Indigo",
            .brown: "Brown",
            .gold: "Gold",
            .silver: "Silver",
            .magenta: "Magenta",
            .lime: "Lime",
            .coral: "Coral",
            .crimson: "Crimson",
            .navy: "Navy",
            .lavender: "Lavender",
            .emerald: "Emerald",
            .amber: "Amber",
            .rose: "Rose",
            .rust: "Rust",
            .christmas: "Christmas",
            .halloween: "Halloween",
            .valentine: "Valentine's",
            .patriotic: "Patriotic",
            .easter: "Easter"
        ]
    }
}

extension NumberStyle: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Numbers" }
    static var caseDisplayRepresentations: [NumberStyle: DisplayRepresentation] {
        [
            .normal: "Normal",
            .neon: "Neon",
            .chalk: "Chalk",
            .segments: "Segments",
            .dotMatrix: "Dot Matrix",
            .script: "Script",
            .calligraphy: "Calligraphy",
            .mono: "Mono",
            .rounded: "Rounded",
            .typewriter: "Typewriter",
            .slab: "Slab",
            .varsity: "Varsity",
            .serif: "Serif",
            .comic: "Comic",
            .engraved: "Engraved",
            .editorial: "Editorial",
            .royal: "Royal",
            .analog: "Analog"
        ]
    }
}

extension NeonBloom: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Bloom" }
    static var caseDisplayRepresentations: [NeonBloom: DisplayRepresentation] {
        [
            .off: "Off",
            .soft: "Soft",
            .medium: "Medium",
            .strong: "Strong"
        ]
    }
}

extension NumberThickness: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Thickness" }
    static var caseDisplayRepresentations: [NumberThickness: DisplayRepresentation] {
        [
            .thin: "Thin",
            .regular: "Regular",
            .bold: "Bold",
            .heavy: "Heavy"
        ]
    }
}
