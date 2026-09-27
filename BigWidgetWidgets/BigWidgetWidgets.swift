import WidgetKit
import SwiftUI

// MARK: - Timeline

struct BigWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let battery: BatteryReading
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BigWidgetEntry {
        BigWidgetEntry(date: .now, configuration: ConfigurationAppIntent(), battery: BatteryReading(level: 0.82))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> BigWidgetEntry {
        let battery = await BatteryReading.current()
        // The widget gallery shows a sample value when the device reports no battery.
        let shown = context.isPreview && battery.level == nil ? BatteryReading(level: 0.82) : battery
        return BigWidgetEntry(date: .now, configuration: configuration, battery: shown)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<BigWidgetEntry> {
        let battery = await BatteryReading.current()

        // One entry per minute for the next hour keeps the clock ticking; then WidgetKit asks again
        // (which also refreshes the battery reading).
        let calendar = Calendar.current
        let startOfMinute = calendar.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).compactMap { offset -> BigWidgetEntry? in
            guard let date = calendar.date(byAdding: .minute, value: offset, to: startOfMinute) else { return nil }
            return BigWidgetEntry(date: date, configuration: configuration, battery: battery)
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
        .description("Huge neon time, date, and battery. Pick one, two, or all three.")
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
        ReadoutCell(readout: readout, date: entry.date, battery: entry.battery)
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
                    phase: phase,
                    monochrome: !isFullColor,
                    glidesBetweenSteps: true
                )
                .frame(height: max(8, size.height * 0.1))
                .padding(.horizontal, size.width * 0.08)
                .widgetAccentable()
            }
        }
    }

    // MARK: Pieces

    private func lights(_ text: String) -> some View {
        NeonText(
            text: text,
            color: tint,
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
        }
    }
}

// MARK: - Previews

extension ConfigurationAppIntent {
    fileprivate static let timeOnly = ConfigurationAppIntent(time: true, date: false, battery: false)
    fileprivate static let timeAndDate = ConfigurationAppIntent(time: true, date: true, battery: false)
    fileprivate static let all = ConfigurationAppIntent(time: true, date: true, battery: true)
}

private let sampleBattery = BatteryReading(level: 0.82, isCharging: true)

#Preview("Small", as: .systemSmall) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, configuration: .timeOnly, battery: sampleBattery)
    BigWidgetEntry(date: .now.addingTimeInterval(60), configuration: .timeOnly, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .timeAndDate, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .all, battery: sampleBattery)
}

#Preview("Medium", as: .systemMedium) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, configuration: .timeOnly, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .timeAndDate, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .all, battery: sampleBattery)
}

#Preview("Large", as: .systemLarge) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, configuration: .timeAndDate, battery: sampleBattery)
    BigWidgetEntry(date: .now, configuration: .all, battery: sampleBattery)
}
