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
    init(text: String, in available: CGSize, maxStretch: CGFloat = 2.2) {
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
}

// MARK: - Colors

/// Solid, saturated colors for the tubes.
enum NeonColor {
    static let red = Color(red: 1.0, green: 0.08, blue: 0.1)
    static let orange = Color(red: 1.0, green: 0.45, blue: 0.0)
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.0)
    static let green = Color(red: 0.1, green: 0.95, blue: 0.25)
    static let blue = Color(red: 0.1, green: 0.35, blue: 1.0)
    static let purple = Color(red: 0.6, green: 0.15, blue: 1.0)
    static let white = Color(red: 1.0, green: 0.97, blue: 0.92)
    static let pink = Color(red: 1.0, green: 0.2, blue: 0.55)
    static let teal = Color(red: 0.0, green: 0.8, blue: 0.75)
    static let cyan = Color(red: 0.0, green: 0.85, blue: 1.0)
    static let mint = Color(red: 0.3, green: 0.95, blue: 0.7)
    static let indigo = Color(red: 0.4, green: 0.3, blue: 0.95)
    static let brown = Color(red: 0.65, green: 0.4, blue: 0.2)
    static let gold = Color(red: 0.95, green: 0.75, blue: 0.25)
    static let silver = Color(red: 0.75, green: 0.78, blue: 0.84)

    static let spectrum = [red, orange, yellow, green, blue, purple]

    // Holiday palettes: cycled per character, the same way `spectrum` is for Rainbow.
    static let christmas = [red, green, gold]
    static let halloween = [orange, purple, green]
    static let valentine = [pink, red]
    static let patriotic = [red, white, blue]
    static let easter = [pink, cyan, mint, yellow]
}

// MARK: - Style

/// Which colors the tubes are.
enum NeonScheme: String, CaseIterable, Codable, Sendable {
    /// Each readout has its own color: blue time, red date, battery colored by charge.
    case classic
    /// Every character a different color.
    case rainbow
    case red, orange, yellow, green, blue, purple, white
    case pink, teal, cyan, mint, indigo, brown, gold, silver
    case christmas, halloween, valentine, patriotic, easter

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
        case .pink: "Pink"
        case .teal: "Teal"
        case .cyan: "Cyan"
        case .mint: "Mint"
        case .indigo: "Indigo"
        case .brown: "Brown"
        case .gold: "Gold"
        case .silver: "Silver"
        case .christmas: "Christmas"
        case .halloween: "Halloween"
        case .valentine: "Valentine's"
        case .patriotic: "Patriotic"
        case .easter: "Easter"
        }
    }

    /// Whether every character gets its own color from a cycling palette, like Rainbow — these can't
    /// be drawn as a single combined shape the way a one-color scheme can.
    var isMultiColor: Bool {
        switch self {
        case .rainbow, .christmas, .halloween, .valentine, .patriotic, .easter: true
        default: false
        }
    }
}

/// Everything about how numbers look. (Named for the original neon style; it covers every number style.)
struct NeonStyle: Equatable, Sendable, Codable {
    var scheme: NeonScheme = .classic
    var numbers: NumberStyle = .normal
    var bloom: NeonBloom = .soft
    var thickness: NumberThickness = .regular

    /// True when every character shares one color, so a whole number can be drawn as a single shape
    /// (much cheaper, which matters in widgets).
    var isUniform: Bool { !scheme.isMultiColor }

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
        case .pink: NeonColor.pink
        case .teal: NeonColor.teal
        case .cyan: NeonColor.cyan
        case .mint: NeonColor.mint
        case .indigo: NeonColor.indigo
        case .brown: NeonColor.brown
        case .gold: NeonColor.gold
        case .silver: NeonColor.silver
        case .christmas: NeonColor.christmas[index % NeonColor.christmas.count]
        case .halloween: NeonColor.halloween[index % NeonColor.halloween.count]
        case .valentine: NeonColor.valentine[index % NeonColor.valentine.count]
        case .patriotic: NeonColor.patriotic[index % NeonColor.patriotic.count]
        case .easter: NeonColor.easter[index % NeonColor.easter.count]
        }
    }

    /// A combination that's random for `date`'s minute and `element` (e.g. one readout among
    /// several shown at once): the same for every call with that minute and element (so the app and
    /// any matching widgets agree without talking to each other, and every precomputed entry for
    /// that minute matches), different for the next minute, and independent of every other element
    /// showing at the same time — so with four readouts on screen, Random gives each its own
    /// combination instead of all four sharing one.
    static func random(for date: Date, element: Int = 0) -> NeonStyle {
        let minute = Int64(date.timeIntervalSinceReferenceDate / 60)
        let seed = UInt64(bitPattern: minute) ^ (UInt64(bitPattern: Int64(element)) &* 0x9E3779B97F4A7C15)
        var generator = SeededGenerator(seed: seed)
        return NeonStyle(
            scheme: NeonScheme.allCases.randomElement(using: &generator)!,
            numbers: NumberStyle.allCases.randomElement(using: &generator)!,
            bloom: NeonBloom.allCases.randomElement(using: &generator)!,
            thickness: NumberThickness.allCases.randomElement(using: &generator)!
        )
    }
}

/// A small deterministic random source (SplitMix64), so `NeonStyle.random(for:)` gives the same
/// answer for the same minute every time it's asked, in any process.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Views

/// Numbers drawn as bent glass neon tubes.
struct NeonText: View {
    let text: String
    /// The readout's own color, used by the Classic scheme.
    var color: Color = NeonColor.blue
    var style = NeonStyle()
    /// Plain white tubes for tinted / clear widget styles, where the system flattens colors.
    var monochrome = false
    /// Cheaper glow without blurs, and one tube per number when possible. Widgets use this so
    /// WidgetKit can render every timeline entry quickly and within its memory limit.
    var lightweight = false
    var maxStretch: CGFloat = 2.2

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

    /// The whole number as one tube: every character shares color.
    private func combinedTube(_ layout: NeonLayout) -> some View {
        let path = layout.glyphs.reduce(into: Path()) { $0.addPath($1.path) }
        let tube = monochrome ? .white : style.tubeColor(index: 0, readout: color)
        return NeonTube(
            path: path,
            width: layout.tubeWidth * style.thickness.multiplier,
            color: tube,
            lightweight: lightweight,
            bloom: style.bloom.multiplier
        )
    }

    private func perCharacterTubes(_ layout: NeonLayout) -> some View {
        ZStack {
            ForEach(layout.glyphs.indices, id: \.self) { index in
                let glyph = layout.glyphs[index]
                let tube = monochrome ? .white : style.tubeColor(index: index, readout: color)
                NeonTube(
                    path: glyph.path,
                    width: layout.tubeWidth * style.thickness.multiplier,
                    color: tube,
                    lightweight: lightweight,
                    bloom: style.bloom.multiplier
                )
            }
        }
    }
}

/// A glass neon tube along any path: dark glass rim, saturated gas, hot core, glass highlight, soft glow.
struct NeonTube: View {
    var path: Path
    var width: CGFloat
    var color: Color
    /// Unlit tubes (e.g. the empty part of the battery meter) show as dark glass only.
    var isLit = true
    /// Cheaper drawing for widgets.
    var lightweight = false
    /// Glow strength, 0 (none) to 1 (full).
    var bloom: Double = 1

    var body: some View {
        ZStack {
            if isLit && bloom > 0 {
                // Glow cast onto whatever is behind the tube.
                glow(path, color, width * (1.4 + 1.2 * bloom), opacity: 0.6 * bloom)
            }

            // Glass tube wall: a darker rim gives the tube its round, solid body.
            stroke(path, color.mix(with: .black, by: isLit ? 0.55 : 0.8), width)
            if isLit {
                stroke(path, color, width * 0.72)
                stroke(path, color.mix(with: .white, by: 0.4), width * 0.36)
            }
            // Specular highlight along the upper-left of the glass.
            stroke(path, .white.opacity(isLit ? 0.55 : 0.25), width * 0.12)
                .offset(x: -width * 0.17, y: -width * 0.17)
        }
        .modifier(CompositingIfNeeded(isEnabled: !lightweight))
    }

    /// A soft halo behind the tube. One blur per tube; in widgets each number is a single tube
    /// (see `NeonText.lightweight`), which keeps the number of blurs small.
    private func glow(_ path: Path, _ color: Color, _ lineWidth: CGFloat, opacity: Double) -> some View {
        stroke(path, color, lineWidth)
            .blur(radius: lineWidth * 0.46)
            .opacity(opacity)
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

/// A battery meter as a straight neon tube: the charged part is lit, the rest is dark glass.
struct NeonMeter: View {
    var level: Double
    var color: Color
    var style = NeonStyle()
    var monochrome = false
    var lightweight = false

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.height * 0.45, proxy.size.width * 0.06)
            let y = proxy.size.height / 2
            let start = CGPoint(x: width, y: y)
            let end = CGPoint(x: proxy.size.width - width, y: y)
            let split = CGPoint(x: start.x + (end.x - start.x) * min(max(level, 0), 1), y: y)
            let tube = monochrome ? .white : style.tubeColor(index: 0, readout: color)

            ZStack {
                NeonTube(
                    path: Path { $0.move(to: split); $0.addLine(to: end) },
                    width: width, color: tube, isLit: false, lightweight: lightweight
                )
                if level > 0 {
                    NeonTube(
                        path: Path { $0.move(to: start); $0.addLine(to: split) },
                        width: width, color: tube, lightweight: lightweight, bloom: style.bloom.multiplier
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 12) {
        NeonText(text: "12:34", color: NeonColor.blue, style: .init(scheme: .classic))
        NeonText(text: "56789", style: .init(scheme: .rainbow))
        NeonText(text: "72°", style: .init(scheme: .purple))
        NeonText(text: "27", style: .init(scheme: .white))
        NeonText(text: "82%", color: NeonColor.green, style: .init(scheme: .orange))
        NeonMeter(level: 0.82, color: NeonColor.green)
            .frame(height: 24)
    }
    .padding()
    .background(.black)
}
