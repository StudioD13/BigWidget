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
        case "°": 0.55
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
        case "°": [arc(0.27, 0.3, 0.2, 0.2, 0, 360)]
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

/// The tube paths for a piece of text (one per character), sized to fill a space.
struct NeonLayout {
    struct Glyph {
        var path = Path()
        /// Tube length in points, used to space the traveling light pulses.
        var length: CGFloat = 0
    }

    var glyphs: [Glyph] = []
    var size: CGSize = .zero
    var tubeWidth: CGFloat = 0
    /// Points per glyph unit, and the vertical stretch applied to the 1 × 1.6 glyph box.
    var unit: CGFloat = 0
    var stretch: CGFloat = 1
    /// Each character and its left edge, in glyph units. Other number styles draw from these.
    var placements: [(character: Character, x: CGFloat)] = []

    /// Room for thickness and glow around the centerlines (in glyph units).
    static let margin: CGFloat = 0.2

    /// Converts a point in a character's glyph box to view coordinates.
    func point(_ p: CGPoint, inCharacterAt x: CGFloat) -> CGPoint {
        CGPoint(x: (x + p.x) * unit, y: (Self.margin + p.y * stretch) * unit)
    }

    /// Digits are sized by width, then made taller (up to `maxStretch`) to use spare height.
    /// Only the path is stretched; tube thickness stays constant, so the digits get tall and thin.
    init(text: String, in available: CGSize, maxStretch: CGFloat = 1.4) {
        let characters = Array(text)
        guard !characters.isEmpty, available.width > 0, available.height > 0 else { return }

        let totalAdvance = characters.map(NeonGlyphs.advance).reduce(0, +)
            + NeonGlyphs.gap * CGFloat(characters.count - 1)
        let margin = Self.margin
        let unit = min(
            available.width / (totalAdvance + margin * 2),
            available.height / (NeonGlyphs.height + margin * 2)
        )
        let naturalHeight = (NeonGlyphs.height + margin * 2) * unit
        let stretch = min(max(available.height / naturalHeight, 1), maxStretch)

        tubeWidth = unit * 0.15
        self.unit = unit
        self.stretch = stretch
        size = CGSize(width: (totalAdvance + margin * 2) * unit, height: naturalHeight * stretch)

        var cursor = margin
        for character in characters {
            placements.append((character, cursor))
            var glyph = Glyph()
            for stroke in NeonGlyphs.strokes(character) {
                let points = stroke.map {
                    CGPoint(x: (cursor + $0.x) * unit, y: (margin + $0.y * stretch) * unit)
                }
                if points.count == 1 {
                    // A dot: a tiny segment that the round line cap turns into a bead of neon.
                    glyph.path.move(to: points[0])
                    glyph.path.addLine(to: CGPoint(x: points[0].x, y: points[0].y + 0.01))
                    glyph.length += tubeWidth
                } else {
                    glyph.path.addLines(points)
                    glyph.length += zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
                }
            }
            if !glyph.path.isEmpty { glyphs.append(glyph) }
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

/// Solid, saturated colors for the tubes and the lights that course through them.
enum NeonColor {
    static let red = Color(red: 1.0, green: 0.08, blue: 0.1)
    static let orange = Color(red: 1.0, green: 0.45, blue: 0.0)
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.0)
    static let green = Color(red: 0.1, green: 0.95, blue: 0.25)
    static let blue = Color(red: 0.1, green: 0.35, blue: 1.0)
    static let purple = Color(red: 0.6, green: 0.15, blue: 1.0)
    static let white = Color(red: 1.0, green: 0.97, blue: 0.92)

    static let spectrum = [red, orange, yellow, green, blue, purple]

    /// Contrasting primaries to run through a tube of the given color.
    static func contrasting(_ tube: Color) -> [Color] {
        switch tube {
        case red: [yellow, blue]
        case blue: [yellow, red]
        case yellow: [red, blue]
        case orange: [blue, yellow]
        case purple: [yellow, green]
        case white: [red, blue]
        default: [yellow, blue]
        }
    }
}

// MARK: - Style

/// Which colors the tubes are.
enum NeonScheme: String, CaseIterable, Codable, Sendable {
    /// Each readout has its own color: blue time, red date, battery colored by charge.
    case classic
    /// Every character a different color.
    case rainbow
    case red, orange, yellow, green, blue, purple, white

    var title: String {
        switch self {
        case .classic: "Classic"
        case .rainbow: "Rainbow"
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        case .white: "White"
        }
    }
}

/// What the light inside the tubes does.
enum NeonEffect: String, CaseIterable, Codable, Sendable {
    /// Pulses of contrasting color travel through the tubes.
    case coursing
    /// White-hot sparks travel through the tubes.
    case sparkle
    /// Pulses cycle through every color of the rainbow.
    case spectrum
    /// The whole sign slowly glows brighter and dimmer.
    case breathe
    /// An old sign: characters now and then sputter and dim.
    case flicker
    /// Solid, steady light.
    case steady

    var title: String {
        switch self {
        case .coursing: "Coursing"
        case .sparkle: "Sparkle"
        case .spectrum: "Spectrum"
        case .breathe: "Breathe"
        case .flicker: "Flicker"
        case .steady: "Steady"
        }
    }
}

/// How fast the light moves.
enum NeonSpeed: String, CaseIterable, Codable, Sendable {
    case slow, normal, fast, turbo

    var title: String {
        switch self {
        case .slow: "Slow"
        case .normal: "Normal"
        case .fast: "Fast"
        case .turbo: "Turbo"
        }
    }

    /// Multiplier applied to how far the light travels per second (app) or per update (widgets).
    var multiplier: Double {
        switch self {
        case .slow: 0.5
        case .normal: 1
        case .fast: 2
        case .turbo: 4
        }
    }
}

/// Everything about how numbers look. (Named for the original neon style; it covers every number style.)
struct NeonStyle: Equatable, Sendable {
    var scheme: NeonScheme = .classic
    var effect: NeonEffect = .coursing
    var speed: NeonSpeed = .normal
    var numbers: NumberStyle = .neon
    var bloom: NeonBloom = .soft

    /// True when every character shares one color and brightness, so a whole number
    /// can be drawn as a single tube (much cheaper, which matters in widgets).
    var isUniform: Bool { scheme != .rainbow && effect != .flicker }

    /// The tube color for character `index`, given the readout's own color (used by `.classic`).
    func tubeColor(index: Int, readout: Color) -> Color {
        switch scheme {
        case .classic: readout
        case .rainbow: NeonColor.spectrum[index % NeonColor.spectrum.count]
        case .red: NeonColor.red
        case .orange: NeonColor.orange
        case .yellow: NeonColor.yellow
        case .green: NeonColor.green
        case .blue: NeonColor.blue
        case .purple: NeonColor.purple
        case .white: NeonColor.white
        }
    }

    func pulseColors(for tube: Color) -> [Color] {
        switch effect {
        case .coursing: NeonColor.contrasting(tube)
        case .sparkle: [.white]
        case .spectrum: NeonColor.spectrum
        case .breathe, .flicker, .steady: []
        }
    }

    /// Brightness (0...1) of character `index` at `phase`.
    func brightness(index: Int, phase: Double) -> Double {
        switch effect {
        case .breathe:
            return 0.62 + 0.38 * sin(phase * 26)
        case .flicker:
            // Roughly one character in six sputters at any moment.
            let step = Int((phase * 25).rounded(.down))
            return Self.hash(index, step) % 6 == 0 ? 0.22 : 1
        default:
            return 1
        }
    }

    private static func hash(_ a: Int, _ b: Int) -> Int {
        var h = UInt64(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663)
        h ^= h >> 13
        h = h &* 0x5bd1_e995
        h ^= h >> 15
        return Int(h % 1_000_003)
    }
}

// MARK: - Views

/// Numbers drawn as bent glass neon tubes, with colored light coursing through them.
struct NeonText: View {
    let text: String
    /// The readout's own color, used by the Classic scheme.
    var color: Color = NeonColor.blue
    var style = NeonStyle()
    /// How far the light has traveled. The app advances this continuously;
    /// widgets step it once per timeline entry and let it glide.
    var phase: Double = 0
    /// Plain white tubes for tinted / clear widget styles, where the system flattens colors.
    var monochrome = false
    /// Animate each step to the next `phase` (for widgets, which update in steps).
    var glidesBetweenSteps = false
    /// Cheaper glow without blurs, and one tube per number when possible. Widgets use this so
    /// WidgetKit can render every timeline entry quickly and within its memory limit.
    var lightweight = false
    var maxStretch: CGFloat = 1.4

    var body: some View {
        GeometryReader { proxy in
            let layout = NeonLayout(text: text, in: proxy.size, maxStretch: maxStretch)
            Group {
                if lightweight && style.isUniform {
                    combinedTube(layout)
                } else {
                    perCharacterTubes(layout)
                }
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// The whole number as one tube: every character shares color and brightness.
    private func combinedTube(_ layout: NeonLayout) -> some View {
        let path = layout.glyphs.reduce(into: Path()) { $0.addPath($1.path) }
        let length = layout.glyphs.reduce(0) { $0 + $1.length }
        let tube = monochrome ? Color.white : style.tubeColor(index: 0, readout: color)
        let pulses = style.pulseColors(for: tube)
        return NeonTube(
            path: path,
            width: layout.tubeWidth,
            color: tube,
            pulseColors: monochrome && !pulses.isEmpty ? [.white] : pulses,
            pulseCount: max(1, Int(length / (layout.tubeWidth * 14))),
            phase: phase,
            brightness: style.brightness(index: 0, phase: phase),
            glidesBetweenSteps: glidesBetweenSteps,
            lightweight: lightweight,
            bloom: style.bloom.multiplier
        )
    }

    private func perCharacterTubes(_ layout: NeonLayout) -> some View {
        ZStack {
                ForEach(layout.glyphs.indices, id: \.self) { index in
                    let glyph = layout.glyphs[index]
                    let tube = monochrome ? Color.white : style.tubeColor(index: index, readout: color)
                    let pulses = style.pulseColors(for: tube)
                    NeonTube(
                        path: glyph.path,
                        width: layout.tubeWidth,
                        color: tube,
                        pulseColors: monochrome && !pulses.isEmpty ? [.white] : pulses,
                        pulseCount: max(1, Int(glyph.length / (layout.tubeWidth * 14))),
                        // Offset each character so pulses don't march in lockstep.
                        phase: phase + Double(index) * 0.31,
                        brightness: style.brightness(index: index, phase: phase),
                        glidesBetweenSteps: glidesBetweenSteps,
                        lightweight: lightweight,
                        bloom: style.bloom.multiplier
                    )
                }
        }
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
    /// 0...1; dims the gas and glow (breathe and flicker effects).
    var brightness: Double = 1
    var glidesBetweenSteps = false
    /// Unlit tubes (e.g. the empty part of the battery meter) show as dark glass only.
    var isLit = true
    /// Cheaper drawing for widgets.
    var lightweight = false
    /// Glow strength, 0 (none) to 1 (full).
    var bloom: Double = 1

    private var stepAnimation: Animation? {
        glidesBetweenSteps ? .easeInOut(duration: 1.9) : nil
    }

    var body: some View {
        ZStack {
            if isLit && bloom > 0 {
                // Glow cast onto whatever is behind the tube.
                glow(path, color, width * (1.4 + 1.2 * bloom), opacity: 0.6 * brightness * bloom)
            }

            // Glass tube wall: a darker rim gives the tube its round, solid body.
            stroke(path, color.mix(with: .black, by: isLit ? 0.55 : 0.8), width)
            if isLit {
                Group {
                    stroke(path, color, width * 0.72)
                    stroke(path, color.mix(with: .white, by: 0.4), width * 0.36)
                }
                .opacity(0.35 + 0.65 * brightness)
                pulses
            }
            // Specular highlight along the upper-left of the glass.
            stroke(path, .white.opacity(isLit ? 0.55 : 0.25), width * 0.12)
                .offset(x: -width * 0.17, y: -width * 0.17)
        }
        .modifier(CompositingIfNeeded(isEnabled: !lightweight))
        .animation(stepAnimation, value: brightness)
    }

    /// A soft halo behind the tube. One blur per tube; in widgets each number is a single tube
    /// (see `NeonText.lightweight`), which keeps the number of blurs small.
    private func glow(_ path: Path, _ color: Color, _ lineWidth: CGFloat, opacity: Double) -> some View {
        stroke(path, color, lineWidth)
            .blur(radius: lineWidth * 0.46)
            .opacity(opacity)
    }

    /// Short bright slugs of contrasting color racing along the tube.
    private var pulses: some View {
        ForEach(pulseColors.indices, id: \.self) { group in
            // Each color gets its own pulses; together they alternate along the tube.
            let shape = PulseShape(
                path: path,
                offset: phase,
                count: pulseCount * pulseColors.count,
                // Pulses cover about a fifth of the tube, so the tube's own color stays dominant.
                length: min(0.06, 0.2 / Double(max(pulseCount * pulseColors.count, 1))),
                groups: pulseColors.count,
                group: group
            )
            let pulseColor = pulseColors[group]
            ZStack {
                if bloom > 0 {
                    if lightweight {
                        // Pulses are short, so a plain soft stroke reads as glow without another blur.
                        shape.stroke(pulseColor.opacity(0.35 * bloom), style: Self.style(width * (1 + 0.5 * bloom)))
                    } else {
                        shape.stroke(pulseColor, style: Self.style(width * (1.2 + 0.8 * bloom)))
                            .blur(radius: width * 0.9 * bloom)
                            .opacity(0.8 * bloom)
                    }
                }
                shape.stroke(pulseColor, style: Self.style(width * 0.72))
                shape.stroke(pulseColor.mix(with: .white, by: 0.6), style: Self.style(width * 0.3))
            }
            .animation(stepAnimation, value: phase)
        }
    }

    private func stroke(_ path: Path, _ color: Color, _ lineWidth: CGFloat) -> some View {
        path.stroke(color, style: Self.style(lineWidth))
    }

    private static func style(_ lineWidth: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }
}

/// Applies `compositingGroup()` only when asked (it costs an offscreen pass).
private struct CompositingIfNeeded: ViewModifier {
    var isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled { content.compositingGroup() } else { content }
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
    var style = NeonStyle()
    var phase: Double = 0
    var monochrome = false
    var glidesBetweenSteps = false
    var lightweight = false

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.height * 0.45, proxy.size.width * 0.06)
            let y = proxy.size.height / 2
            let start = CGPoint(x: width, y: y)
            let end = CGPoint(x: proxy.size.width - width, y: y)
            let split = CGPoint(x: start.x + (end.x - start.x) * min(max(level, 0), 1), y: y)
            let tube = monochrome ? Color.white : style.tubeColor(index: 0, readout: color)
            let pulses = style.pulseColors(for: tube)

            ZStack {
                NeonTube(
                    path: Path { $0.move(to: split); $0.addLine(to: end) },
                    width: width, color: tube, pulseColors: [], pulseCount: 0, phase: 0, isLit: false,
                    lightweight: lightweight
                )
                if level > 0 {
                    NeonTube(
                        path: Path { $0.move(to: start); $0.addLine(to: split) },
                        width: width,
                        color: tube,
                        pulseColors: monochrome && !pulses.isEmpty ? [.white] : pulses,
                        pulseCount: isCharging ? 3 : 1,
                        phase: phase,
                        brightness: style.brightness(index: 0, phase: phase),
                        glidesBetweenSteps: glidesBetweenSteps,
                        lightweight: lightweight,
                        bloom: style.bloom.multiplier
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
    VStack(spacing: 12) {
        NeonText(text: "12:34", color: NeonColor.blue, style: .init(scheme: .classic, effect: .coursing), phase: 0.1)
        NeonText(text: "56789", style: .init(scheme: .rainbow, effect: .sparkle), phase: 0.3)
        NeonText(text: "72°", style: .init(scheme: .purple, effect: .spectrum), phase: 0.2)
        NeonText(text: "27", style: .init(scheme: .white, effect: .flicker), phase: 0.44)
        NeonText(text: "82%", color: NeonColor.green, style: .init(scheme: .orange, effect: .breathe), phase: 0.4)
        NeonMeter(level: 0.82, color: NeonColor.green, isCharging: true, phase: 0.2)
            .frame(height: 24)
    }
    .padding()
    .background(.black)
}
