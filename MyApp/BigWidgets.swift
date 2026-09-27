import SwiftUI

// MARK: - Time

struct TimeWidget: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            GlassTile(tint: ReadoutFormat.timeTint) {
                BigReadout(caption: "TIME", value: ReadoutFormat.clock(date), tint: ReadoutFormat.timeTint) {
                    if let period = ReadoutFormat.period(date) {
                        Text(period)
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.primary.opacity(0.8))
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
                    caption: ReadoutFormat.weekday(date),
                    value: ReadoutFormat.day(date),
                    tint: ReadoutFormat.dateTint
                ) {
                    Text(ReadoutFormat.month(date))
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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

    var body: some View {
        let tint = ReadoutFormat.batteryTint(monitor.level)
        let valueText = ReadoutFormat.battery(monitor.level)

        GlassTile(tint: tint) {
            BigReadout(caption: monitor.isCharging ? "CHARGING" : "BATTERY", value: valueText, tint: tint) {
                BubbleGauge(level: monitor.level ?? 0, tint: tint, isCharging: monitor.isCharging)
                    .frame(height: 28)
                    .padding(.horizontal, 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitor.level == nil ? "Battery level unavailable" : "Battery \(valueText)\(monitor.isCharging ? ", charging" : "")")
    }
}
