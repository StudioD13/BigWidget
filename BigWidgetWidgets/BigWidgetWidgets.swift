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
                // Transparent: the bubbly numbers float right on the wallpaper.
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("BigWidget")
        .description("Huge, bubbly time, date, and battery. Pick one, two, or all three.")
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

/// One readout, sized so the number fills nearly all of its space.
/// Small labels sit beside the number when the cell is wide, or tight above it when it's tall.
struct ReadoutCell: View {
    var readout: Readout
    var date: Date
    var battery: BatteryReading

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let labelSize = min(max(size.height * 0.13, 10), 26)

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
            // No "TIME" label — a clock is self-explanatory. AM/PM tucks in at the digits' bottom corner.
            let period = ReadoutFormat.period(date)
            let periodWidth = period == nil ? 0 : labelSize * 1.7
            let digitsSpace = CGSize(width: size.width - periodWidth, height: size.height)

            HStack(alignment: .bottom, spacing: 2) {
                if size.width < size.height * 1.4 {
                    // Squarish or tall: stack hours over minutes so the digits fill the space.
                    let parts = ReadoutFormat.clockParts(date)
                    let gap = size.height * 0.03
                    let lineSpace = CGSize(width: digitsSpace.width, height: (digitsSpace.height - gap) / 2)
                    // Size both lines as two digits so they match even when the hour is one digit.
                    let fit = BubbleText.Fit("00", in: lineSpace)
                    VStack(spacing: gap) {
                        number(parts.hour, fit: fit, width: lineSpace.width)
                        number(parts.minute, fit: fit, width: lineSpace.width)
                    }
                } else {
                    number(ReadoutFormat.clock(date), in: digitsSpace)
                }
                if let period {
                    label(period, size: labelSize * 0.9)
                        .frame(width: periodWidth, alignment: .leading)
                }
            }

        case .date:
            if size.width > size.height * 1.3 {
                // Wide: weekday and month stacked to the right of the day number.
                let sideWidth = labelSize * 2.6
                HStack(spacing: 4) {
                    number(ReadoutFormat.day(date), in: CGSize(width: size.width - sideWidth, height: size.height))
                    VStack(alignment: .leading, spacing: 0) {
                        label(ReadoutFormat.shortWeekday(date), size: labelSize)
                        label(ReadoutFormat.shortMonth(date), size: labelSize)
                    }
                    .frame(width: sideWidth, alignment: .leading)
                }
            } else {
                // Tall: one tight line above the day number.
                let lineHeight = labelSize * 1.2
                VStack(spacing: 0) {
                    label("\(ReadoutFormat.shortWeekday(date)) · \(ReadoutFormat.shortMonth(date))", size: labelSize)
                        .frame(height: lineHeight)
                    number(ReadoutFormat.day(date), in: CGSize(width: size.width, height: size.height - lineHeight))
                }
            }

        case .battery:
            let gaugeHeight = max(6, size.height * 0.09)
            VStack(spacing: gaugeHeight * 0.6) {
                number(ReadoutFormat.battery(battery.level), in: CGSize(width: size.width, height: size.height - gaugeHeight * 1.6))
                BubbleGauge(level: battery.level ?? 0, tint: tint, isCharging: battery.isCharging)
                    .frame(width: size.width * 0.8, height: gaugeHeight)
            }
        }
    }

    // MARK: Pieces

    /// A number sized to fill `space`. Its frame is only as tall as the visible glyphs,
    /// so neighbors (AM/PM, the battery gauge) sit right against it.
    private func number(_ text: String, in space: CGSize) -> some View {
        number(text, fit: BubbleText.Fit(text, in: space), width: space.width)
    }

    private func number(_ text: String, fit: BubbleText.Fit, width: CGFloat) -> some View {
        BubbleText(
            text: text,
            tint: tint,
            fit: fit,
            animated: false,
            flat: renderingMode != .fullColor
        )
        .widgetAccentable()
        .frame(width: width)
    }

    private func label(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(renderingMode == .fullColor ? tint.mix(with: .white, by: 0.25) : .primary)
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
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
