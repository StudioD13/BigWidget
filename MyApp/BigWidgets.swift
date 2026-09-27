import SwiftUI

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

    @Environment(\.lightPhase) private var phase

    var body: some View {
        let tint = ReadoutFormat.batteryTint(monitor.level)
        let valueText = ReadoutFormat.battery(monitor.level)

        GlassTile(tint: tint) {
            // The % sign and bulb meter say "battery"; no caption needed.
            BigReadout(caption: nil, value: valueText, tint: tint) {
                NeonMeter(level: monitor.level ?? 0, color: tint, isCharging: monitor.isCharging, phase: phase)
                    .frame(height: 22)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitor.level == nil ? "Battery level unavailable" : "Battery \(valueText)\(monitor.isCharging ? ", charging" : "")")
    }
}
