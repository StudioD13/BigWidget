import WidgetKit
import SwiftUI
import Synchronization
import OSLog

// MARK: - Timeline

struct BigWidgetEntry: TimelineEntry {
    let date: Date
    /// Resolved when the timeline is built (the app's shared choices or the widget's own).
    let readouts: [Readout]
    /// Each readout's own style — independent per readout when Random is on, so four readouts
    /// showing at once don't all share one combination.
    let styles: [Readout: NeonStyle]
    let battery: BatteryReading
    var weather: WeatherReading?
    /// Shown in place of the conditions while there's no reading, saying what's needed.
    var weatherNote = Provider.weatherNote

    func style(for readout: Readout) -> NeonStyle {
        styles[readout] ?? NeonStyle()
    }

    /// For the common case: every readout shares one manually-chosen style.
    init(
        date: Date, readouts: [Readout], style: NeonStyle, battery: BatteryReading,
        weather: WeatherReading? = nil, weatherNote: String = Provider.weatherNote
    ) {
        self.date = date
        self.readouts = readouts
        self.styles = Dictionary(uniqueKeysWithValues: Readout.allCases.map { ($0, style) })
        self.battery = battery
        self.weather = weather
        self.weatherNote = weatherNote
    }

    /// For Random: each readout gets its own independent style.
    init(
        date: Date, readouts: [Readout], styles: [Readout: NeonStyle], battery: BatteryReading,
        weather: WeatherReading? = nil, weatherNote: String = Provider.weatherNote
    ) {
        self.date = date
        self.readouts = readouts
        self.styles = styles
        self.battery = battery
        self.weather = weather
        self.weatherNote = weatherNote
    }
}

/// Builds every timeline instantly from saved data. Until a timeline arrives, WidgetKit shows a
/// placeholder (or nothing), and it asks for one whenever a widget is added, resized, edited, or
/// reloaded — so nothing here waits on location or the network. Weather refreshes in the
/// background instead and reloads the widgets when a new reading lands.
struct Provider: AppIntentTimelineProvider {
    /// A saved reading younger than this is current; an older one triggers a background refresh.
    private static let weatherFreshness: TimeInterval = 60
    /// A saved reading older than this is too stale to show.
    private static let weatherMaxAge: TimeInterval = 3 * 60 * 60
    /// How soon to ask WidgetKit to rebuild the timeline again — every time, not just while weather
    /// is stale — so a widget that's actually being looked at keeps both battery and weather close
    /// to live. This is a request, not a guarantee: WidgetKit's daily refresh budget decides how
    /// often it's actually honored, and it leans toward granting more of that budget to widgets
    /// people are actually viewing. Asking this often for a widget nobody's looking at just means
    /// the budget quietly throttles it back down — which is the right outcome, not a bug.
    private static let refreshInterval: TimeInterval = 60

    /// What each timeline was built from, so a widget that looks wrong can be traced to its inputs.
    private static let logger = Logger(subsystem: "Studio-D.BigWidget", category: "Widget")

    func placeholder(in context: Context) -> BigWidgetEntry {
        // Shown while a timeline is built (e.g. right after resizing). The placeholder doesn't know
        // which widget it stands in for, so it's plain black: any readouts or colors could be
        // another widget's, which is worse than a brief moment of nothing.
        BigWidgetEntry(date: .now, readouts: [], style: NeonStyle(), battery: BatteryReading())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> BigWidgetEntry {
        // Snapshots (the widget gallery, the edit sheet) use saved data, with samples in the gallery.
        let battery = await BatteryReading.current()
        let shownBattery = context.isPreview && battery.level == nil ? BatteryReading(level: 0.82) : battery
        let readouts = configuration.readouts
        var weather = readouts.contains(.weather) ? Self.showableWeather : nil
        if readouts.contains(.weather) && weather == nil && context.isPreview { weather = .sample }
        return BigWidgetEntry(
            date: .now, readouts: readouts, styles: Self.styles(for: configuration, at: .now),
            battery: shownBattery, weather: weather
        )
    }

    /// Every readout's style at `date`, resolved together so Random can give each its own.
    private static func styles(for configuration: ConfigurationAppIntent, at date: Date) -> [Readout: NeonStyle] {
        Dictionary(uniqueKeysWithValues: Readout.allCases.map { ($0, configuration.style(for: $0, at: date)) })
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<BigWidgetEntry> {
        let battery = await BatteryReading.current()
        let readouts = configuration.readouts
        let showsWeather = readouts.contains(.weather)
        let weather = showsWeather ? Self.showableWeather : nil
        let loggedStyle = configuration.style(for: .time, at: .now)
        Self.logger.notice("""
            Timeline: matchApp=\(configuration.matchAppStyle, privacy: .public) \
            isRandom=\(configuration.isRandom, privacy: .public) \
            readouts=\(readouts.map(\.rawValue).joined(separator: ","), privacy: .public) \
            numbers=\(loggedStyle.numbers.rawValue, privacy: .public) scheme=\(loggedStyle.scheme.rawValue, privacy: .public) \
            thickness=\(loggedStyle.thickness.rawValue, privacy: .public) \
            savedLocation=\(SharedStore.lastLocation != nil, privacy: .public) savedWeather=\(SharedStore.cachedWeather != nil, privacy: .public)
            """)

        let needsWeather = showsWeather && !Self.hasFreshWeather
        if needsWeather {
            WeatherRefresh.start()
        }

        // One entry per minute for the next hour keeps the clock ticking; then WidgetKit asks again
        // (which also refreshes the battery reading). Each entry resolves its own style, so Random
        // lands on a different combination minute to minute, precomputed for the whole hour at once.
        let calendar = Calendar.current
        let startOfMinute = calendar.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).compactMap { offset -> BigWidgetEntry? in
            guard let date = calendar.date(byAdding: .minute, value: offset, to: startOfMinute) else { return nil }
            return BigWidgetEntry(
                date: date, readouts: readouts, styles: Self.styles(for: configuration, at: date), battery: battery, weather: weather
            )
        }
        // Always ask back soon, whether or not weather happens to be fresh right now — someone
        // looking at the widget for the next five minutes wants the battery and weather it shows to
        // keep tracking reality for that whole five minutes, not just until the first reading lands.
        let policy: TimelineReloadPolicy = .after(.now.addingTimeInterval(Self.refreshInterval))
        return Timeline(entries: entries, policy: policy)
    }

    /// The saved reading, unless it's too old to be worth showing.
    private static var showableWeather: WeatherReading? {
        guard let saved = SharedStore.cachedWeather,
              Date.now.timeIntervalSince(saved.date) < weatherMaxAge
        else { return nil }
        return saved.reading
    }

    /// Without a saved location there's no weather until the app has been opened and allowed to
    /// use location (a widget can't ask for permission itself); with one, a reading is on its way.
    static var weatherNote: String {
        SharedStore.lastLocation == nil ? "Open BigWidget" : "Updating…"
    }

    private static var hasFreshWeather: Bool {
        guard let saved = SharedStore.cachedWeather else { return false }
        return Date.now.timeIntervalSince(saved.date) < weatherFreshness
    }
}

/// Fetches weather off the timeline's path, one lookup at a time for every widget in the extension.
/// `WeatherReading.fetch` saves new readings to the App Group; the widgets reload only when the
/// reading actually changed, and the reloaded timeline then finds it fresh, so this can't loop.
private enum WeatherRefresh {
    private static let isRunning = Mutex(false)
    /// Long enough for a slow location fix, WeatherKit, and the National Weather Service fallback.
    private static let limit: Duration = .seconds(25)

    static func start() {
        let alreadyRunning = isRunning.withLock { running in
            defer { running = true }
            return running
        }
        guard !alreadyRunning else { return }

        Task.detached(priority: .utility) {
            let before = SharedStore.cachedWeather?.reading
            let fresh = await withTimeLimit(limit) {
                await WeatherReading.current(locationTimeout: .seconds(5))
            }
            isRunning.withLock { $0 = false }
            if let fresh, fresh != before {
                WidgetCenter.shared.reloadTimelines(ofKind: BigWidgetWidgets.kind)
            }
        }
    }
}

// MARK: - Widget

struct BigWidgetWidgets: Widget {
    static let kind = "BigWidgetWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BigWidgetEntryView(entry: entry)
                // Black, so the neon is the only light (the system can still remove it, e.g. in StandBy).
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("BigWidget")
        .description("Huge neon time, date, battery, and weather. Show any combination.")
        .containerBackgroundRemovable(true)
        .supportedFamilies(Self.families)
        .contentMarginsDisabled()
    }

    private static var families: [WidgetFamily] {
        #if os(visionOS)
        // visionOS's own extra-large widget is the portrait variant (`.systemExtraLarge` without
        // "Portrait" is for an iOS/iPadOS app running in visionOS compatibility mode, not a native
        // visionOS app like this one).
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait]
        #else
        // `.systemExtraLarge` (landscape) is iPad- and Mac-only. `.systemExtraLargePortrait` is the
        // one that actually reaches the iPhone Home Screen — on large-screened and foldable iPhones
        // (confirmed on iPhone Duo unfolded) — as well as iPad's Today View and the Mac desktop.
        // Declaring both costs nothing on a device that only has one or neither.
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait]
        #endif
    }
}

// MARK: - Layout

struct BigWidgetEntryView: View {
    var entry: BigWidgetEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    /// True in StandBy's Night Mode (and similar Always-On-style contexts): keep the glow, but turn
    /// it down so the widget isn't blazing in a dark room.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private let spacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 6) {
            readoutGrid
            if !entry.readouts.isEmpty {
                minuteSweep
            }
        }
        .padding(10)
        // The background is always black, so labels are always light.
        .environment(\.colorScheme, .dark)
    }

    /// A thin neon bar that fills steadily across each minute. Widgets can't run their own
    /// animation; a timer-driven progress view is the one thing the system keeps moving live,
    /// so this is what keeps the widget visibly alive between the once-a-minute updates.
    private var minuteSweep: some View {
        let leadStyle = entry.style(for: entry.readouts[0])
        let color = renderingMode == .fullColor
            ? leadStyle.tubeColor(index: 0, readout: tint(of: entry.readouts[0]))
            : .white
        let bloom = isLuminanceReduced ? leadStyle.bloom.multiplier * 0.3 : leadStyle.bloom.multiplier
        return ProgressView(timerInterval: entry.date...entry.date.addingTimeInterval(60), countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(color)
        .shadow(color: color.opacity(0.8 * max(bloom, 0.3)), radius: 4)
        .widgetAccentable()
        .accessibilityHidden(true)
    }

    /// Each readout's own color, used by the Classic scheme.
    private func tint(of readout: Readout) -> Color {
        switch readout {
        case .time: ReadoutFormat.timeTint
        case .date: ReadoutFormat.dateTint
        case .battery: ReadoutFormat.batteryTint(entry.battery.level)
        case .weather: ReadoutFormat.weatherTint(celsius: entry.weather?.celsius)
        }
    }

    @ViewBuilder
    private var readoutGrid: some View {
        let readouts = entry.readouts

        GeometryReader { proxy in
            switch (readouts.count, family) {
            case (1, _):
                cell(readouts[0])

            case (4, _):
                // All four: Time gets its own top row — full width, so nothing dilutes its size
                // priority — and the other three share a row underneath.
                let rows = [[readouts[0]], [readouts[1], readouts[2], readouts[3]]]
                let rowHeight = usable(proxy.size.height, gaps: 1, spacing: spacing)
                let bottomWidth = usable(proxy.size.width, gaps: 2, spacing: spacing * 3)
                VStack(spacing: spacing) {
                    cell(readouts[0]).frame(height: rowHeight * share(rows[0], in: rows))
                    HStack(spacing: spacing * 3) {
                        ForEach(rows[1], id: \.self) { readout in
                            cell(readout).frame(width: bottomWidth / 3)
                        }
                    }
                    .frame(height: rowHeight * share(rows[1], in: rows))
                }

            case (_, .systemSmall), (2, .systemLarge), (2, .systemExtraLargePortrait):
                // Stack vertically when the widget is squarish or tall. Time gets extra height.
                let usableHeight = usable(proxy.size.height, gaps: readouts.count - 1, spacing: spacing)
                VStack(spacing: spacing) {
                    ForEach(readouts, id: \.self) { readout in
                        cell(readout).frame(height: usableHeight * share(readout, in: readouts))
                    }
                }

            case (3, .systemLarge), (3, .systemExtraLargePortrait):
                // Time across the top (with extra height), the other two side by side below.
                let rows = [[readouts[0]], [readouts[1], readouts[2]]]
                let rowHeight = usable(proxy.size.height, gaps: 1, spacing: spacing)
                let bottomWidth = usable(proxy.size.width, gaps: 1, spacing: spacing * 3)
                VStack(spacing: spacing) {
                    cell(readouts[0]).frame(height: rowHeight * share(rows[0], in: rows))
                    HStack(spacing: spacing * 3) {
                        ForEach(rows[1], id: \.self) { readout in
                            cell(readout).frame(width: bottomWidth * share(readout, in: rows[1]))
                        }
                    }
                    .frame(height: rowHeight * share(rows[1], in: rows))
                }

            default:
                // Medium and extra large are wide: side by side. Time gets extra width.
                let usableWidth = usable(proxy.size.width, gaps: readouts.count - 1, spacing: spacing * 3)
                HStack(spacing: spacing * 3) {
                    ForEach(readouts, id: \.self) { readout in
                        cell(readout).frame(width: usableWidth * share(readout, in: readouts))
                    }
                }
            }
        }
    }

    /// `total`, minus room for `gaps` gaps of `spacing` each — the space actually left for cells
    /// once a stack's own spacing is accounted for.
    private func usable(_ total: CGFloat, gaps: Int, spacing: CGFloat) -> CGFloat {
        total - spacing * CGFloat(max(gaps, 0))
    }

    /// The fraction of its row/column a readout gets: 1.6× for Time (it's the thing people check
    /// most, so it earns extra room whenever it's on screen), split evenly otherwise.
    private func share(_ readout: Readout, in readouts: [Readout]) -> CGFloat {
        guard readouts.count > 1 else { return 1 }
        guard readouts.contains(.time) else { return 1 / CGFloat(readouts.count) }
        let lead: CGFloat = 1.6
        let total = lead + CGFloat(readouts.count - 1)
        return (readout == .time ? lead : 1) / total
    }

    /// The fraction of the stack a row gets: extra for whichever row contains Time.
    private func share(_ row: [Readout], in rows: [[Readout]]) -> CGFloat {
        guard rows.count > 1 else { return 1 }
        guard rows.contains(where: { $0.contains(.time) }) else { return 1 / CGFloat(rows.count) }
        let lead: CGFloat = 1.6
        let total = lead + CGFloat(rows.count - 1)
        return (row.contains(.time) ? lead : 1) / total
    }

    private func cell(_ readout: Readout) -> some View {
        ReadoutCell(
            readout: readout,
            date: entry.date,
            battery: entry.battery,
            weather: entry.weather,
            weatherNote: entry.weatherNote,
            style: dimmed(entry.style(for: readout))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Turns bloom down one notch in StandBy's Night Mode / Always-On-style contexts.
    private func dimmed(_ style: NeonStyle) -> NeonStyle {
        guard isLuminanceReduced, let index = NeonBloom.allCases.firstIndex(of: style.bloom), index > 0 else { return style }
        var style = style
        style.bloom = NeonBloom.allCases[index - 1]
        return style
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
    var weatherNote = "Updating…"
    var style: NeonStyle

    @Environment(\.widgetRenderingMode) private var renderingMode

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
            // Always one horizontal "h:mm" line; never stacked, regardless of the cell's shape.
            let period = ReadoutFormat.period(date)
            let periodWidth = period == nil ? 0 : labelSize * 1.7

            HStack(alignment: .bottom, spacing: 0) {
                lights(ReadoutFormat.clock(date))
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
            // The meter is a thin accent strip, not the main event, so the number gets almost all
            // the space. Charging is a clear badge instead, so it still reads once the strip is this thin.
            VStack(spacing: 2) {
                lights(ReadoutFormat.battery(battery.level))
                DisplayMeter(
                    level: battery.level ?? 0,
                    color: tint,
                    style: style,
                    monochrome: !isFullColor,
                    lightweight: true
                )
                .frame(height: min(max(5, size.height * 0.035), 12))
                .padding(.horizontal, size.width * 0.1)
                .widgetAccentable()
            }
            .overlay(alignment: .topTrailing) {
                if battery.isCharging {
                    let color = isFullColor ? tint : .white
                    Image(systemName: "bolt.fill")
                        .font(.system(size: labelSize * 1.3, weight: .black))
                        .foregroundStyle(color)
                        .shadow(color: color.opacity(style.bloom.multiplier), radius: labelSize * 0.15 * style.bloom.multiplier)
                        .widgetAccentable()
                }
            }

        case .weather:
            let temperature = weather?.temperature ?? "--°"
            let condition = weather?.condition ?? weatherNote
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
        let bloom = style.bloom.multiplier
        return Image(systemName: weather?.symbolName ?? "questionmark")
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color.mix(with: .white, by: 0.3))
            .shadow(color: color.opacity(bloom), radius: size * 0.12 * bloom)
            .widgetAccentable()
    }

    private func lights(_ text: String) -> some View {
        DisplayText(
            text: text,
            color: tint,
            style: style,
            monochrome: !isFullColor,
            lightweight: true
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
    // A style of their own (Match App off), so previews show exactly these readouts.
    fileprivate static let timeOnly = ConfigurationAppIntent(time: true, date: false, battery: false, style: NeonStyle())
    fileprivate static let timeAndDate = ConfigurationAppIntent(time: true, date: true, battery: false, style: NeonStyle())
    fileprivate static let all = ConfigurationAppIntent(time: true, date: true, battery: true, weather: true, style: NeonStyle())
    fileprivate static let weatherOnly = ConfigurationAppIntent(time: false, date: false, battery: false, weather: true, style: NeonStyle())
}

private let sampleBattery = BatteryReading(level: 0.82, isCharging: true)

private let previewStyles: [String: NeonStyle] = [
    "timeOnly": NeonStyle(scheme: .classic),
    "timeAndDate": NeonStyle(scheme: .rainbow),
    "all": NeonStyle(scheme: .classic, numbers: .chalk),
    "weatherOnly": NeonStyle(scheme: .purple, numbers: .segments)
]

#Preview("Small", as: .systemSmall) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.weatherOnly.readouts, style: previewStyles["weatherOnly"]!, battery: sampleBattery, weather: .sample)
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.timeOnly.readouts, style: previewStyles["timeOnly"]!, battery: sampleBattery)
    BigWidgetEntry(date: .now.addingTimeInterval(60), readouts: ConfigurationAppIntent.timeOnly.readouts, style: previewStyles["timeOnly"]!, battery: sampleBattery)
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.timeAndDate.readouts, style: previewStyles["timeAndDate"]!, battery: sampleBattery)
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.all.readouts, style: previewStyles["all"]!, battery: sampleBattery, weather: .sample)
}

#Preview("Medium", as: .systemMedium) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.timeOnly.readouts, style: previewStyles["timeOnly"]!, battery: sampleBattery)
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.timeAndDate.readouts, style: previewStyles["timeAndDate"]!, battery: sampleBattery)
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.all.readouts, style: previewStyles["all"]!, battery: sampleBattery, weather: .sample)
}

#Preview("Large", as: .systemLarge) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.timeAndDate.readouts, style: previewStyles["timeAndDate"]!, battery: sampleBattery)
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.all.readouts, style: previewStyles["all"]!, battery: sampleBattery, weather: .sample)
}

#Preview("Extra Large Portrait", as: .systemExtraLargePortrait) {
    BigWidgetWidgets()
} timeline: {
    BigWidgetEntry(date: .now, readouts: ConfigurationAppIntent.all.readouts, style: previewStyles["all"]!, battery: sampleBattery, weather: .sample)
}

/// All four readouts, each with its own independently random style — confirms Random no longer
/// gives every readout the same combination.
#Preview("Random", as: .systemLarge) {
    BigWidgetWidgets()
} timeline: {
    let readouts = Readout.allCases
    let styles = Dictionary(uniqueKeysWithValues: readouts.map { ($0, NeonStyle.random(for: .now, element: $0.randomSeed)) })
    BigWidgetEntry(date: .now, readouts: readouts, styles: styles, battery: sampleBattery, weather: .sample)
}
