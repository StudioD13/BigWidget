import SwiftUI
import WeatherKit

// MARK: - Time

struct TimeWidget: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            GlassTile(tint: ReadoutFormat.timeTint) {
                // No caption: a clock is self-explanatory.
                BigReadout(caption: nil, value: ReadoutFormat.clock(date), tint: ReadoutFormat.timeTint) {
                    if let period = ReadoutFormat.period(date) {
                        Text(period)
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(ReadoutFormat.timeTint.mix(with: .primary, by: 0.35))
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(date.formatted(date: .omitted, time: .shortened))
        }
    }
}

// MARK: - Date

struct DateWidget: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            GlassTile(tint: ReadoutFormat.dateTint) {
                BigReadout(
                    caption: "\(ReadoutFormat.shortWeekday(date)) · \(ReadoutFormat.month(date))",
                    value: ReadoutFormat.day(date),
                    tint: ReadoutFormat.dateTint
                ) {
                    EmptyView()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        }
    }
}

// MARK: - Battery

struct BatteryWidget: View {
    var monitor: BatteryMonitor

    @Environment(\.neonStyle) private var style

    var body: some View {
        let tint = ReadoutFormat.batteryTint(monitor.level)
        let valueText = ReadoutFormat.battery(monitor.level)

        GlassTile(tint: tint) {
            GeometryReader { proxy in
                // The % sign says "battery"; no caption needed. The meter is a thin accent strip,
                // not the main event, so the number gets almost all the space.
                BigReadout(caption: nil, value: valueText, tint: tint) {
                    DisplayMeter(level: monitor.level ?? 0, color: tint, style: style)
                        .frame(height: min(max(5, proxy.size.height * 0.035), 12))
                        .padding(.horizontal, proxy.size.width * 0.14)
                        .padding(.bottom, 4)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay(alignment: .topTrailing) {
                    // Charging needs to read at a glance, so it's a clear badge, not something
                    // buried in the now-thin meter strip.
                    if monitor.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: proxy.size.height * 0.14, weight: .black))
                            .foregroundStyle(tint)
                            .shadow(color: tint.opacity(style.bloom.multiplier), radius: proxy.size.height * 0.02 * style.bloom.multiplier)
                            .padding(proxy.size.height * 0.06)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitor.level == nil ? "Battery level unavailable" : "Battery \(valueText)\(monitor.isCharging ? ", charging" : "")")
    }
}

// MARK: - Weather

struct WeatherWidget: View {
    var monitor: WeatherMonitor

    @Environment(\.neonStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let reading = monitor.reading
        let tint = ReadoutFormat.weatherTint(celsius: reading?.celsius)
        let caption = reading?.condition ?? monitor.statusText

        GlassTile(tint: tint) {
            VStack(spacing: 2) {
                BigReadout(caption: nil, value: reading?.temperature ?? "--°", tint: tint) {
                    HStack(spacing: 6) {
                        if let symbol = reading?.symbolName {
                            let glow = style.tubeColor(index: 0, readout: tint)
                            Image(systemName: symbol)
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(glow.mix(with: .white, by: 0.3))
                                .shadow(color: glow.opacity(style.bloom.multiplier), radius: 6 * style.bloom.multiplier)
                        }
                        Text(caption)
                            .foregroundStyle(tint.mix(with: .primary, by: 0.35))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                }
                attributionView
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.map { "\($0.temperature), \($0.condition)" } ?? caption)
    }

    /// Credits whichever service supplied the reading. WeatherKit requires the Apple Weather mark and a
    /// legal link; National Weather Service readings name the station they were measured at; MET
    /// Norway's CC BY 4.0 license just needs a name and a link.
    @ViewBuilder
    private var attributionView: some View {
        if let reading = monitor.reading, reading.source == .metNorway {
            Link("MET Norway", destination: MetNorwayWeatherService.attributionURL)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else if let reading = monitor.reading, reading.source == .nationalWeatherService {
            Link(
                reading.station.map { "National Weather Service · \($0)" } ?? "National Weather Service",
                destination: NationalWeatherService.attributionURL
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else if let attribution = monitor.attribution {
            HStack(spacing: 8) {
                AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(attribution.serviceName)
                }
                .frame(height: 11)
                Link("Legal", destination: attribution.legalPageURL)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }
}
