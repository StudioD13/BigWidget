import WidgetKit
import SwiftUI

// MARK: - Timeline

struct BigWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let battery: BatteryReading
    var weather: WeatherReading?
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BigWidgetEntry {
        BigWidgetEntry(date: .now, configuration: ConfigurationAppIntent(), battery: BatteryReading(level: 0.82), weather: .sample)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> BigWidgetEntry {
        let battery = await BatteryReading.current()
        // The widget gallery shows a sample value when the device reports no battery.
        let shown = context.isPreview && battery.level == nil ? BatteryReading(level: 0.82) : battery
        let weather = configuration.showWeather ? await WeatherReading.current() : nil
        return BigWidgetEntry(
            date: .now, configuration: configuration, battery: shown,
            weather: weather ?? (context.isPreview ? .sample : nil)
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<BigWidgetEntry> {
        let battery = await BatteryReading.current()
        let weather = configuration.showWeather ? await WeatherReading.current() : nil

        // One entry per minute for the next hour keeps the clock ticking; then WidgetKit asks again
        // (which also refreshes the battery and weather readings).
        let calendar = Calendar.current
        let startOfMinute = calendar.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).compactMap { offset -> BigWidgetEntry? in
            guard let date = calendar.date(byAdding: .minute, value: offset, to: startOfMinute) else { return nil }
            return BigWidgetEntry(date: date, configuration: configuration, battery: battery, weather: weather)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Widget

struct BigWidgetWidgets: Widget {
    let kind: String = "BigWidgetWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BigWidgetEntryView(entry: entry)
                // Clear, removable background: as close to no background as WidgetKit allows.
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("BigWidget")
        .description("Huge neon time, date, battery, and weather. Show any combination.")
        .containerBackgroundRemovable(true)
        .supportedFamilies(Self.families)
        .contentMarginsDisabled()
    }

    private static var families: [WidgetFamily] {
        #if os(visionOS)
        [.systemSmall, .systemMedium, .systemLarge]
        #else
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        #endif
    }
}

// MARK: - Layout

struct BigWidgetEntryView: View {
    var entry: BigWidgetEntry

    @Environment(\.widgetFamily) private var family

    private let spacing: CGFloat = 4

    var body: some View {
        let readouts = entry.configuration.readouts

        Group {
            switch (readouts.count, family) {
            case (1, _):
                cell(readouts[0])

            case (4, _):
                // All four: a 2 × 2 grid.
                VStack(spacing: spacing) {
                    HStack(spacing: spacing * 3) {
                        cell(readouts[0])
                        cell(readouts[1])
                    }
                    HStack(spacing: spacing * 3) {
                        cell(readouts[2])
                        cell(readouts[3])
                    }
                }

            case (_, .systemSmall), (2, .systemLarge):
                // Stack vertically when the widget is squarish or tall.
                VStack(spacing: spacing) {
                    ForEach(readouts, id: \.self) { cell($0) }
                }

            case (3, .systemLarge):
                // First readout across the top, the other two side by side.
                VStack(spacing: spacing) {
                    cell(readouts[0])
                    HStack(spacing: spacing * 3) {
                        cell(readouts[1])
                        cell(readouts[2])
                    }
                }

            default:
                // Medium and extra large are wide: side by side.
                HStack(spacing: spacing * 3) {
                    ForEach(readouts, id: \.self) { cell($0) }
                }
            }
        }
        .padding(10)
    }

    private func cell(_ readout: Readout) -> some View {
        ReadoutCell(
            readout: readout,
            date: entry.date,
            battery: entry.battery,
            weather: entry.weather,
            style: entry.configuration.style
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Cell

/// One readout drawn in neon tubes, sized so the tubes fill nearly all of its space.
/// Small labels sit beside the number when the cell is wide, or tight above it when it's tall.
struct ReadoutCell: View {
    var readout: Readout
    var date: Date
    var battery: BatteryReading
    var weather: WeatherReading?
    var style: NeonStyle

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Widgets can't animate continuously, so the light coursing through the tubes advances once per
    /// timeline entry (each minute) and glides to its new spot — a brief light show as the minute changes.
    private var phase: Double {
        (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 0.137
    }

    private var isFullColor: Bool { renderingMode == .fullColor }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let labelSize = min(max(size.height * 0.12, 10), 24)

            content(in: size, labelSize: labelSize)
                .frame(width: size.width, height: size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func content(in size: CGSize, labelSize: CGFloat) -> some View {
        switch readout {
        case .time:
            // No "TIME" label — a clock is self-explanatory. AM/PM tucks in at the bottom corner.
            let period = ReadoutFormat.period(date)
            let periodWidth = period == nil ? 0 : labelSize * 1.7
            let digitsSpace = CGSize(width: size.width - periodWidth, height: size.height)

            HStack(alignment: .bottom, spacing: 0) {
                if NeonLayout.prefersStackedClock(in: digitsSpace) {
                    // Squarish or tall: hours over minutes makes much bigger digits.
                    let parts = ReadoutFormat.clockParts(date)
                    VStack(spacing: 0) {
                        lights(parts.hour.count == 1 ? " \(parts.hour)" : parts.hour)
                        lights(parts.minute)
                    }
                } else {
                    lights(ReadoutFormat.clock(date))
                }
                if let period {
                    label(period, size: labelSize * 0.85)
                        .frame(width: periodWidth, alignment: .leading)
                        .padding(.bottom, labelSize * 0.4)
                }
            }

        case .date:
            if size.width > size.height * 1.3 {
                // Wide: weekday and month stacked to the right of the day number.
                HStack(spacing: 4) {
                    lights(ReadoutFormat.day(date))
                    VStack(alignment: .leading, spacing: 0) {
                        label(ReadoutFormat.shortWeekday(date), size: labelSize)
                        label(ReadoutFormat.shortMonth(date), size: labelSize)
                    }
                    .frame(width: labelSize * 2.6, alignment: .leading)
                }
            } else {
                // Tall: one tight line above the day number.
                VStack(spacing: 0) {
                    label("\(ReadoutFormat.shortWeekday(date)) · \(ReadoutFormat.shortMonth(date))", size: labelSize)
                        .frame(height: labelSize * 1.2)
                    lights(ReadoutFormat.day(date))
                }
            }

        case .battery:
            VStack(spacing: 2) {
                lights(ReadoutFormat.battery(battery.level))
                NeonMeter(
                    level: battery.level ?? 0,
                    color: tint,
                    isCharging: battery.isCharging,
                    style: style,
                    phase: phase,
                    monochrome: !isFullColor,
                    glidesBetweenSteps: true
                )
                .frame(height: max(8, size.height * 0.1))
                .padding(.horizontal, size.width * 0.08)
                .widgetAccentable()
            }

        case .weather:
            let temperature = weather?.temperature ?? "--°"
            let condition = weather?.condition ?? "No Weather"
            if size.width > size.height * 1.3 {
                // Wide: conditions icon and text beside the temperature.
                HStack(spacing: 4) {
                    lights(temperature)
                    VStack(alignment: .leading, spacing: 2) {
                        conditionIcon(size: labelSize * 2)
                        label(condition, size: labelSize * 0.8)
                    }
                    .frame(width: labelSize * 4, alignment: .leading)
                }
            } else {
                // Tall: icon and conditions on one line above the temperature.
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        conditionIcon(size: labelSize * 1.1)
                        label(condition, size: labelSize)
                    }
                    .frame(height: labelSize * 1.3)
                    lights(temperature)
                }
            }
        }
    }

    // MARK: Pieces

    /// The WeatherKit condition symbol, lit like neon.
    private func conditionIcon(size: CGFloat) -> some View {
        let color = isFullColor ? style.tubeColor(index: 0, readout: tint) : .white
        return Image(systemName: weather?.symbolName ?? "questionmark")
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color.mix(with: .white, by: 0.3))
            .shadow(color: color, radius: size * 0.12)
            .shadow(color: color.opacity(0.6), radius: size * 0.35)
            .widgetAccentable()
    }

    private func lights(_ text: String) -> some View {
        NeonText(
            text: text,
            color: tint,
            style: style,
            phase: phase,
            monochrome: !isFullColor,
            glidesBetweenSteps: true
        )
        .widgetAccentable()
    }

    private func label(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    // MARK: Content

    private var tint: Color {
        switch readout {
        case .time: ReadoutFormat.timeTint
        case .date: ReadoutFormat.dateTint
        case .battery: ReadoutFormat.batteryTint(battery.level)
        case .weather: ReadoutFormat.weatherTint(celsius: weather?.celsius)
        }
    }

    private var accessibilityText: String {
        switch readout {
        case .time:
            date.formatted(date: .omitted, time: .shortened)
        case .date:
            date.formatted(date: .complete, time: .omitted)
        case .battery:
            battery.level == nil
                ? "Battery level unavailable"
                : "Battery \(ReadoutFormat.battery(battery.level))\(battery.isCharging ? ", charging" : "")"
        case .weather:
            weather.map { "\($0.temperature), \($0.condition)" } ?? "Weather unavailable"
        }
    }
}

// MARK: - Previews

extension ConfigurationAppIntent {
    fileprivate static let timeOnly = ConfigurationAppIntent(time: true, date: false, battery: false)
    fileprivate static let timeAndDate = ConfigurationAppIntent(time: true, date: true, battery: false, scheme: .rainbow, effect: .sparkle)
    fileprivate static let all = ConfigurationAppIntent(time: true, date: true, battery: true, weather: true)
    fileprivate static let weatherOnly = ConfigurationAppIntent(time: false, date: false, battery: false, weather: true, scheme: .purple, effect: .spectrum)
}

private let sampleBattery = BatteryReading(level: 0.82, isCharging: true)

#Preview("Small", as: .systemSmall) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, configuration: .weatherOnly, battery: sampleBattery, weather: .sample)
    BigWidgetEntry(date: .now, configuration: .timeOnly, battery: sampleBattery)
    BigWidgetEntry(date: .now.addingTimeInterval(60), configuration: .timeOnly, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .timeAndDate, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .all, battery: sampleBattery, weather: .sample)
}

#Preview("Medium", as: .systemMedium) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, configuration: .timeOnly, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .timeAndDate, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .all, battery: sampleBattery, weather: .sample)
}

#Preview("Large", as: .systemLarge) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, configuration: .timeAndDate, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .all, battery: sampleBattery, weather: .sample)
}
