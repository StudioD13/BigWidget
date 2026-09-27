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
                .containerBackground(for: .widget) { WidgetBackdrop() }
        }
        .configurationDisplayName("BigWidget")
        .description("Huge, bubbly time, date, and battery. Pick one, two, or all three.")
        .supportedFamilies(Self.families)
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

    private let spacing: CGFloat = 8

    var body: some View {
        let readouts = entry.configuration.readouts
        let paneled = readouts.count > 1

        switch (readouts.count, family) {
        case (1, _):
            cell(readouts[0], paneled: false)

        case (_, .systemSmall), (2, .systemLarge):
            // Stack vertically when the widget is squarish or tall.
            VStack(spacing: spacing) {
                ForEach(readouts, id: \.self) { cell($0, paneled: paneled) }
            }

        case (3, .systemLarge):
            // First readout across the top, the other two side by side.
            VStack(spacing: spacing) {
                cell(readouts[0], paneled: true)
                HStack(spacing: spacing) {
                    cell(readouts[1], paneled: true)
                    cell(readouts[2], paneled: true)
                }
            }

        default:
            // Medium and extra large are wide: side by side.
            HStack(spacing: spacing) {
                ForEach(readouts, id: \.self) { cell($0, paneled: paneled) }
            }
        }
    }

    private func cell(_ readout: Readout, paneled: Bool) -> some View {
        ReadoutCell(readout: readout, date: entry.date, battery: entry.battery)
            .padding(paneled ? 6 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if paneled { GlassPanel() }
            }
    }
}

// MARK: - Cell

/// One readout: optional caption, huge bubbly value, optional footer.
/// Captions and footers drop away automatically when the cell is too small, so the number stays big.
struct ReadoutCell: View {
    var readout: Readout
    var date: Date
    var battery: BatteryReading

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { proxy in
            let roomy = proxy.size.height > 96
            let labelSize = min(max(proxy.size.height * 0.1, 11), 22)

            VStack(spacing: 0) {
                if roomy {
                    label(caption(narrow: proxy.size.width < 150), size: labelSize)
                }

                GeometryReader { valueProxy in
                    value(size: BubbleText.fittingSize(for: valueText, in: valueProxy.size))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if roomy {
                    footer(labelSize: labelSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Pieces

    @ViewBuilder
    private func value(size: CGFloat) -> some View {
        if renderingMode == .fullColor {
            BubbleText(text: valueText, tint: tint, size: size, animated: false)
        } else {
            // Tinted/clear Home Screen styles flatten colors, so use a clean heavy numeral instead.
            Text(valueText)
                .font(.system(size: size, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())
                .widgetAccentable()
        }
    }

    private func label(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(.primary.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private func footer(labelSize: CGFloat) -> some View {
        switch readout {
        case .time:
            if let period = ReadoutFormat.period(date) {
                label(period, size: labelSize)
            }
        case .date:
            label(ReadoutFormat.month(date), size: labelSize)
        case .battery:
            BubbleGauge(level: battery.level ?? 0, tint: tint, isCharging: battery.isCharging)
                .frame(height: labelSize * 0.8)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
        }
    }

    // MARK: Content

    private var valueText: String {
        switch readout {
        case .time: ReadoutFormat.clock(date)
        case .date: ReadoutFormat.day(date)
        case .battery: ReadoutFormat.battery(battery.level)
        }
    }

    private func caption(narrow: Bool) -> String {
        switch readout {
        case .time: "TIME"
        case .date: narrow ? ReadoutFormat.shortWeekday(date) : ReadoutFormat.weekday(date)
        case .battery: battery.isCharging ? "CHARGING" : "BATTERY"
        }
    }

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
                : "Battery \(valueText)\(battery.isCharging ? ", charging" : "")"
        }
    }
}

// MARK: - Styling

/// A frosted, glass-like pane behind each readout when a widget shows more than one.
struct GlassPanel: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        shape
            .fill(.white.opacity(renderingMode == .fullColor ? 0.18 : 0.08))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
    }
}

/// A still version of the app's colorful mesh, for the widget background.
struct WidgetBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.55, 0], [1, 0],
                [0, 0.45], [0.5, 0.55], [1, 0.4],
                [0, 1], [0.45, 1], [1, 1]
            ],
            colors: colorScheme == .dark
                ? [.indigo, .purple, .blue,
                   .teal, .pink.mix(with: .black, by: 0.3), .indigo,
                   .blue, .mint.mix(with: .black, by: 0.4), .purple]
                : [.cyan, .pink.opacity(0.8), .orange.opacity(0.8),
                   .mint, .yellow.opacity(0.7), .pink,
                   .blue.opacity(0.7), .teal, .purple.opacity(0.7)]
        )
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
