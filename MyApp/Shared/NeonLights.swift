import SwiftUI

// MARK: - Glyphs

/// Hand-drawn centerlines for thin, tall digits (in a 1 × 1.6 box, y pointing down).
/// Neon tubes are bent along these strokes.
enum NeonGlyphs {
    static let height: CGFloat = 1.6
    static let gap: CGFloat = 0.3

    static func advance(_ character: Character) -> CGFloat {
        switch character {
        case ":": 0.3
        case "%": 1.15
        case "-": 0.8
        case " ": 0.5
        default: 1
        }
    }

    /// Strokes for a character, as polylines. A single-point stroke is drawn as a dot.
    static func strokes(_ character: Character) -> [[CGPoint]] {
        switch character {
        case "0": [arc(0.5, 0.8, 0.4, 0.7, 0, 360)]
        case "1": [[p(0.22, 0.38), p(0.55, 0.1), p(0.55, 1.5)]]
        case "2": [arc(0.5, 0.46, 0.38, 0.36, 180, 385) + [p(0.12, 1.5), p(0.9, 1.5)]]
        case "3": [arc(0.5, 0.42, 0.35, 0.32, 195, 450) + arc(0.5, 1.12, 0.4, 0.38, 270, 525)]
        case "4": [[p(0.72, 1.5), p(0.72, 0.1), p(0.1, 1.05), p(0.92, 1.05)]]
        case "5": [[p(0.86, 0.1), p(0.2, 0.1), p(0.16, 0.72)] + arc(0.5, 1.08, 0.4, 0.42, 232, 505)]
        case "6": six
        case "7": [[p(0.1, 0.1), p(0.9, 0.1), p(0.38, 1.5)]]
        case "8": [arc(0.5, 0.41, 0.32, 0.31, 90, 450), arc(0.5, 1.13, 0.4, 0.37, 270, 630)]
        case "9": six.map { $0.map { p(1 - $0.x, height - $0.y) } }
        case ":": [[p(0.15, 0.55)], [p(0.15, 1.05)]]
        case "%": [arc(0.3, 0.35, 0.19, 0.24, 0, 360), [p(0.95, 0.1), p(0.2, 1.5)], arc(0.85, 1.25, 0.19, 0.24, 0, 360)]
        case "-": [[p(0.1, 0.8), p(0.7, 0.8)]]
        default: []
        }
    }

    private static var six: [[CGPoint]] {
        [[p(0.78, 0.1), p(0.16, 0.93)] + arc(0.5, 1.1, 0.38, 0.4, 205, 565)]
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// An elliptical arc; angles in degrees with 0° = right, 90° = down.
    private static func arc(
        _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
        _ from: CGFloat, _ to: CGFloat
    ) -> [CGPoint] {
        let steps = max(8, Int(abs(to - from) / 5))
        return (0...steps).map { i in
            let angle = (from + (to - from) * CGFloat(i) / CGFloat(steps)) * .pi / 180
            return p(cx + rx * cos(angle), cy + ry * sin(angle))
        }
    }
}

// MARK: - Layout

/// The tube path for a piece of text, sized to fill a space.
struct NeonLayout {
    var path = Path()
    var size: CGSize = .zero
    var tubeWidth: CGFloat = 0
    /// Total tube length in points, used to space the traveling light pulses.
    var length: CGFloat = 0

    /// Digits are sized by width, then made taller (up to `maxStretch`) to use spare height.
    /// Only the path is stretched; tube thickness stays constant, so the digits get tall and thin.
    init(text: String, in available: CGSize, maxStretch: CGFloat = 1.4) {
        let characters = Array(text)
        guard !characters.isEmpty, available.width > 0, available.height > 0 else { return }

        let totalAdvance = characters.map(NeonGlyphs.advance).reduce(0, +)
            + NeonGlyphs.gap * CGFloat(characters.count - 1)
        // Room for the tube's thickness and glow around the centerlines (in glyph units).
        let margin: CGFloat = 0.2
        let unit = min(
            available.width / (totalAdvance + margin * 2),
            available.height / (NeonGlyphs.height + margin * 2)
        )
        let naturalHeight = (NeonGlyphs.height + margin * 2) * unit
        let stretch = min(max(available.height / naturalHeight, 1), maxStretch)

        tubeWidth = unit * 0.15
        size = CGSize(width: (totalAdvance + margin * 2) * unit, height: naturalHeight * stretch)

        var cursor = margin
        for character in characters {
            for stroke in NeonGlyphs.strokes(character) {
                let points = stroke.map {
                    CGPoint(x: (cursor + $0.x) * unit, y: (margin + $0.y * stretch) * unit)
                }
                if points.count == 1 {
                    // A dot: a tiny segment that the round line cap turns into a bead of neon.
                    path.move(to: points[0])
                    path.addLine(to: CGPoint(x: points[0].x, y: points[0].y + 0.01))
                    length += tubeWidth
                } else {
                    path.addLines(points)
                    length += zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
                }
            }
            cursor += NeonGlyphs.advance(character) + NeonGlyphs.gap
        }
    }

    /// Whether a clock should stack hours over minutes: true when that makes the tubes noticeably bigger.
    static func prefersStackedClock(in size: CGSize) -> Bool {
        let single = NeonLayout(text: "00:00", in: size).tubeWidth
        let stacked = NeonLayout(text: "00", in: CGSize(width: size.width, height: size.height * 0.48)).tubeWidth
        return stacked > single * 1.15
    }
}

// MARK: - Colors

/// Solid primary colors for the tubes and the lights that course through them.
enum NeonColor {
    static let red = Color(red: 1.0, green: 0.08, blue: 0.1)
    static let blue = Color(red: 0.1, green: 0.35, blue: 1.0)
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.0)
    static let green = Color(red: 0.1, green: 0.95, blue: 0.25)

    /// Contrasting primaries to run through a tube of the given color.
    static func pulses(for tube: Color) -> [Color] {
        switch tube {
        case red: [yellow, blue]
        case blue: [yellow, red]
        case yellow: [red, blue]
        default: [yellow, blue]
        }
    }
}

// MARK: - Views

/// Numbers drawn as bent glass neon tubes, with colored light coursing through them.
struct NeonText: View {
    let text: String
    var color: Color = NeonColor.blue
    /// How far the light pulses have traveled. The app advances this continuously;
    /// widgets step it once per timeline entry and let it glide.
    var phase: Double = 0
    /// Plain white tubes for tinted / clear widget styles, where the system flattens colors.
    var monochrome = false
    /// Animate pulses gliding to each new `phase` (for widgets, which update in steps).
    var glidesBetweenSteps = false
    var maxStretch: CGFloat = 1.4

    var body: some View {
        GeometryReader { proxy in
            let layout = NeonLayout(text: text, in: proxy.size, maxStretch: maxStretch)
            NeonTube(
                path: layout.path,
                width: layout.tubeWidth,
                color: monochrome ? .white : color,
                pulseColors: monochrome ? [.white] : NeonColor.pulses(for: color),
                pulseCount: max(2, Int(layout.length / (layout.tubeWidth * 14))),
                phase: phase,
                glidesBetweenSteps: glidesBetweenSteps
            )
            .frame(width: layout.size.width, height: layout.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// A glass neon tube along any path: dark glass rim, saturated gas, hot core, glass highlight,
/// soft glow, and bright pulses of other colors traveling through it.
struct NeonTube: View {
    var path: Path
    var width: CGFloat
    var color: Color
    var pulseColors: [Color]
    var pulseCount: Int
    var phase: Double
    var glidesBetweenSteps = false
    /// Unlit tubes (e.g. the empty part of the battery meter) show as dark glass only.
    var isLit = true

    var body: some View {
        ZStack {
            if isLit {
                // Glow cast onto whatever is behind the tube.
                stroke(path, color, width * 2.6).blur(radius: width * 1.2).opacity(0.6)
            }

            // Glass tube wall: a darker rim gives the tube its round, solid body.
            stroke(path, color.mix(with: .black, by: isLit ? 0.55 : 0.8), width)
            if isLit {
                stroke(path, color, width * 0.72)
                stroke(path, color.mix(with: .white, by: 0.4), width * 0.36)
                pulses
            }
            // Specular highlight along the upper-left of the glass.
            stroke(path, .white.opacity(isLit ? 0.55 : 0.25), width * 0.12)
                .offset(x: -width * 0.17, y: -width * 0.17)
        }
        .compositingGroup()
    }

    /// Short bright slugs of contrasting color racing along the tube.
    private var pulses: some View {
        ForEach(pulseColors.indices, id: \.self) { group in
            let shape = PulseShape(
                path: path,
                offset: phase,
                count: pulseCount,
                // Pulses cover about a fifth of the tube, so the tube's own color stays dominant.
                length: min(0.06, 0.2 / Double(max(pulseCount, 1))),
                groups: pulseColors.count,
                group: group
            )
            let pulseColor = pulseColors[group]
            ZStack {
                shape.stroke(pulseColor, style: Self.style(width * 2)).blur(radius: width * 0.9).opacity(0.8)
                shape.stroke(pulseColor, style: Self.style(width * 0.72))
                shape.stroke(pulseColor.mix(with: .white, by: 0.6), style: Self.style(width * 0.3))
            }
            .animation(glidesBetweenSteps ? .easeInOut(duration: 1.8) : nil, value: phase)
        }
    }

    private func stroke(_ path: Path, _ color: Color, _ lineWidth: CGFloat) -> some View {
        path.stroke(color, style: Self.style(lineWidth))
    }

    private static func style(_ lineWidth: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }
}

/// Evenly spaced segments of a path, shifted by `offset` (a fraction of the path's length).
/// Animatable, so pulses glide along the tube instead of jumping.
private struct PulseShape: Shape {
    var path: Path
    var offset: Double
    var count: Int
    var length: Double
    /// Pulses are split into color groups: this shape draws every `groups`-th pulse, starting at `group`.
    var groups: Int
    var group: Int

    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var result = Path()
        for index in stride(from: group, to: count, by: max(groups, 1)) {
            var start = (Double(index) / Double(count) + offset).truncatingRemainder(dividingBy: 1)
            if start < 0 { start += 1 }
            let end = start + length
            if end <= 1 {
                result.addPath(path.trimmedPath(from: start, to: end))
            } else {
                result.addPath(path.trimmedPath(from: start, to: 1))
                result.addPath(path.trimmedPath(from: 0, to: end - 1))
            }
        }
        return result
    }
}

/// A battery meter as a straight neon tube: the charged part is lit, the rest is dark glass.
struct NeonMeter: View {
    var level: Double
    var color: Color
    var isCharging: Bool
    var phase: Double = 0
    var monochrome = false
    var glidesBetweenSteps = false

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.height * 0.45, proxy.size.width * 0.06)
            let y = proxy.size.height / 2
            let start = CGPoint(x: width, y: y)
            let end = CGPoint(x: proxy.size.width - width, y: y)
            let split = CGPoint(x: start.x + (end.x - start.x) * min(max(level, 0), 1), y: y)
            let tubeColor = monochrome ? Color.white : color

            ZStack {
                NeonTube(
                    path: Path { $0.move(to: split); $0.addLine(to: end) },
                    width: width, color: tubeColor, pulseColors: [], pulseCount: 0, phase: 0, isLit: false
                )
                if level > 0 {
                    NeonTube(
                        path: Path { $0.move(to: start); $0.addLine(to: split) },
                        width: width,
                        color: tubeColor,
                        pulseColors: monochrome ? [.white] : NeonColor.pulses(for: color),
                        pulseCount: isCharging ? 4 : 2,
                        phase: phase,
                        glidesBetweenSteps: glidesBetweenSteps
                    )
                }
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: width * 2.2, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 16) {
        NeonText(text: "12:34", color: NeonColor.blue, phase: 0.1)
        NeonText(text: "56789", color: NeonColor.red, phase: 0.3)
        NeonText(text: "27", color: NeonColor.red, phase: 0.2)
        NeonText(text: "82%", color: NeonColor.green, phase: 0.4)
        NeonMeter(level: 0.82, color: NeonColor.green, isCharging: true, phase: 0.2)
            .frame(height: 24)
    }
    .padding()
    .background(.black)
}
