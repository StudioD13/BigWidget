import SwiftUI

// MARK: - Settings

/// How the numbers are drawn. Every style is drawn from shapes defined in this project (no fonts),
/// all sized in the same 1 × 1.6 glyph box so layouts work the same for each.
enum NumberStyle: String, CaseIterable, Codable, Sendable {
    /// Plain digits in the system font: no glow, no glass, no gimmick. The default.
    case normal
    /// Bent glass tubes.
    case neon
    /// Hand-drawn chalk on a slate chalkboard.
    case chalk
    /// A seven-segment display, with unlit segments faintly visible.
    case segments
    /// A 5 × 7 grid of lights, like a dot-matrix board.
    case dotMatrix
    /// Flowing cursive handwriting.
    case script
    /// Ornate, flourished calligraphy.
    case calligraphy
    /// A mechanical split-flap display, like an old alarm clock or departure board.
    case flip
    /// A clock face for Time; radial gauges for Battery and Weather; plain digits for Date, which
    /// has no natural analog form.
    case analog

    var title: String {
        switch self {
        case .normal: "Normal"
        case .neon: "Neon"
        case .chalk: "Chalk"
        case .segments: "Segments"
        case .dotMatrix: "Dot Matrix"
        case .script: "Script"
        case .calligraphy: "Calligraphy"
        case .flip: "Flip"
        case .analog: "Analog"
        }
    }

    /// Chalk, Normal, Script, Calligraphy, and Flip are all meant to look plain or realistic, not
    /// glowing, so Bloom doesn't apply to them.
    var usesBloom: Bool { ![.chalk, .normal, .script, .calligraphy, .flip].contains(self) }
}

/// How thick the strokes of the numbers are, in every number style.
enum NumberThickness: String, CaseIterable, Codable, Sendable {
    case thin, regular, bold, heavy

    var title: String {
        switch self {
        case .thin: "Thin"
        case .regular: "Regular"
        case .bold: "Bold"
        case .heavy: "Heavy"
        }
    }

    /// Scales each style's stroke width. Heavy stays below the point where strokes run together.
    var multiplier: CGFloat {
        switch self {
        case .thin: 0.6
        case .regular: 1
        case .bold: 1.4
        case .heavy: 1.8
        }
    }

    /// The matching system font weight, for the Normal number style.
    var fontWeight: Font.Weight {
        switch self {
        case .thin: .light
        case .regular: .regular
        case .bold: .semibold
        case .heavy: .bold
        }
    }
}

/// How much glow spills around the lit numbers. Less bloom keeps digits crisp and easy to tell apart.
enum NeonBloom: String, CaseIterable, Codable, Sendable {
    case off, soft, medium, strong

    var title: String {
        switch self {
        case .off: "Off"
        case .soft: "Soft"
        case .medium: "Medium"
        case .strong: "Strong"
        }
    }

    var multiplier: Double {
        switch self {
        case .off: 0
        case .soft: 0.35
        case .medium: 0.65
        case .strong: 1
        }
    }
}

// MARK: - Dispatcher

/// Draws a number in the chosen `NumberStyle`, filling its space like `NeonText`.
struct DisplayText: View {
    let text: String
    /// The readout's own color, used by the Classic scheme.
    var color: Color = NeonColor.blue
    var style = NeonStyle()
    var monochrome = false
    var lightweight = false

    var body: some View {
        // A soft dark halo keeps light-colored schemes (e.g. White or Yellow) legible on light or
        // clear backgrounds, where the glyphs would otherwise blend in and look blank. It's invisible
        // on dark backgrounds, and skipped in monochrome (accented/vibrant) rendering, where the
        // system supplies its own contrast. Widgets (lightweight) skip it too: the shadows are blurs,
        // which slow WidgetKit's rendering and push it toward its memory limit.
        if monochrome || lightweight {
            glyphs
        } else {
            GeometryReader { proxy in
                let radius = max(1, proxy.size.height * 0.018)
                glyphs
                    .shadow(color: .black.opacity(0.5), radius: radius)
                    .shadow(color: .black.opacity(0.4), radius: radius)
            }
        }
    }

    @ViewBuilder
    private var glyphs: some View {
        switch style.numbers {
        case .normal:
            PlainText(text: text, color: color, style: style, monochrome: monochrome)
        case .neon:
            NeonText(text: text, color: color, style: style, monochrome: monochrome, lightweight: lightweight)
        case .chalk:
            ChalkText(text: text, color: color, style: style, monochrome: monochrome, lightweight: lightweight)
        case .segments:
            SegmentText(text: text, color: color, style: style, monochrome: monochrome, lightweight: lightweight)
        case .dotMatrix:
            DotMatrixText(text: text, color: color, style: style, monochrome: monochrome, lightweight: lightweight)
        case .script:
            ScriptText(text: text, color: color, style: style, monochrome: monochrome)
        case .calligraphy:
            CalligraphyText(text: text, color: color, style: style, monochrome: monochrome)
        case .flip:
            FlipText(text: text, color: color, style: style, monochrome: monochrome)
        case .analog:
            AnalogDisplay(text: text, color: color, style: style, monochrome: monochrome)
        }
    }
}

/// Shared sizing: lays out `text` in the common glyph box and hands each character to `draw`.
private struct GlyphCanvas<Content: View>: View {
    let text: String
    @ViewBuilder var content: (NeonLayout) -> Content

    var body: some View {
        GeometryReader { proxy in
            let layout = NeonLayout(text: text, in: proxy.size)
            content(layout)
                .frame(width: layout.size.width, height: layout.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// The battery meter drawn to match the number style: a chalk line for Chalk, a neon tube otherwise.
/// Charging shows as a bolt badge next to the number (see `ReadoutCell`/`BatteryWidget`), not here,
/// so it's still obvious once the bar shrinks to a thin strip.
struct DisplayMeter: View {
    var level: Double
    var color: Color
    var style = NeonStyle()
    var monochrome = false
    var lightweight = false

    var body: some View {
        switch style.numbers {
        case .chalk:
            ChalkMeter(level: level, color: monochrome ? .white : Color(white: 0.96))
        case .analog:
            // The Analog battery gauge already shows the charge level itself; a bar underneath
            // would be redundant.
            EmptyView()
        case .normal, .script, .calligraphy, .flip:
            PlainMeter(level: level, color: monochrome ? .white : color)
        default:
            NeonMeter(level: level, color: color, style: style, monochrome: monochrome, lightweight: lightweight)
        }
    }
}

// MARK: - Font-based styles (Normal, Script, Calligraphy)

/// Shared engine for any number style drawn with a real font instead of custom-drawn shapes: sizes
/// a huge reference font down with `minimumScaleFactor`, then applies the same width-fit-then-
/// vertical-stretch math every custom-drawn style gets from `NeonLayout`, so a short, wide string
/// like "82%" fills its box here exactly as it would in Neon or Chalk — plain `Text` has no
/// intrinsic reason to fill a container or stretch to use spare height on its own.
/// Per-character color (for Rainbow and the holiday schemes) comes from an attributed string, since
/// SwiftUI's `Text` can't otherwise color individual characters.
private struct FontDrawnText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool
    /// Builds the (huge, reference-size) font to measure and draw with.
    var font: (CGFloat) -> Font

    var body: some View {
        GeometryReader { proxy in
            let layout = NeonLayout(text: text, in: proxy.size)
            let unstretchedHeight = layout.stretch > 0 ? layout.size.height / layout.stretch : layout.size.height
            Text(attributedText)
                .font(font(1000))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .frame(width: layout.size.width, height: unstretchedHeight)
                .scaleEffect(x: 1, y: layout.stretch)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var attributedText: AttributedString {
        var result = AttributedString()
        for (index, character) in text.enumerated() {
            var run = AttributedString(String(character))
            run.foregroundColor = monochrome ? .white : style.tubeColor(index: index, readout: color)
            result += run
        }
        return result
    }
}

/// Plain digits in the system font: no tubes, no glass, no hand-lettering — just numbers.
struct PlainText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool

    var body: some View {
        FontDrawnText(text: text, color: color, style: style, monochrome: monochrome) { size in
            .system(size: size, weight: style.thickness.fontWeight, design: .default)
        }
    }
}

/// Flowing cursive handwriting (Snell Roundhand, bundled with the system). A decorative script
/// typeface has one weight, so Thickness has no effect here.
struct ScriptText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool

    var body: some View {
        FontDrawnText(text: text, color: color, style: style, monochrome: monochrome) { size in
            .custom("SnellRoundhand-Black", size: size)
        }
    }
}

/// Ornate, flourished calligraphy (Zapfino, bundled with the system). One weight, so Thickness has
/// no effect here either.
struct CalligraphyText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool

    var body: some View {
        FontDrawnText(text: text, color: color, style: style, monochrome: monochrome) { size in
            .custom("Zapfino", size: size)
        }
    }
}

/// A plain battery meter: a flat capsule track with a filled, colored bar.
struct PlainMeter: View {
    var level: Double
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.18))
                Capsule().fill(color)
                    .frame(width: proxy.size.width * min(max(level, 0), 1))
            }
            .frame(height: height)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Chalk

/// Hand-lettered chalk: each stroke wobbles a little, each character tilts and sits slightly off the
/// baseline, and a speckled texture lets the board show through like real chalk.
struct ChalkText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool
    var lightweight = false

    var body: some View {
        GlyphCanvas(text: text) { layout in
            let paths = layout.placements.indices.map { index in
                let placement = layout.placements[index]
                return Self.handDrawnPath(placement.character, at: placement.x, seed: index, layout: layout)
            }
            ZStack {
                if lightweight && style.isUniform {
                    // Widgets: the whole number as one chalk stroke (one offscreen pass, not one per character).
                    ChalkStroke(path: paths.reduce(into: Path()) { $0.addPath($1) }, width: layout.unit * 0.14 * style.thickness.multiplier, color: chalkColor(index: 0))
                } else {
                    ForEach(paths.indices, id: \.self) { index in
                        ChalkStroke(path: paths[index], width: layout.unit * 0.14 * style.thickness.multiplier, color: chalkColor(index: index))
                    }
                }
            }
        }
    }

    private func chalkColor(index: Int) -> Color {
        if monochrome { return .white }
        // Classic chalk is white; other schemes use pastel chalk sticks.
        if style.scheme == .classic { return Color(white: 0.96) }
        return style.tubeColor(index: index, readout: color).mix(with: .white, by: 0.45)
    }

    /// The glyph's strokes with a gentle, repeatable hand wobble, tilt, and baseline shift.
    static func handDrawnPath(_ character: Character, at x: CGFloat, seed: Int, layout: NeonLayout) -> Path {
        let s = Double(seed) * 1.7 + Double(character.asciiValue ?? 0) * 0.13
        let tilt = CGFloat(sin(s * 2.1)) * 0.06           // about ±3.5°
        let lift = CGFloat(sin(s * 1.3)) * 0.04
        let center = CGPoint(x: 0.5, y: NeonGlyphs.height / 2)

        var path = Path()
        for (strokeIndex, stroke) in NeonGlyphs.strokes(character).enumerated() {
            let points = stroke.enumerated().map { i, p -> CGPoint in
                let t = Double(i) + Double(strokeIndex) * 11
                let wobble = CGPoint(
                    x: CGFloat(sin(t * 0.45 + s) * 0.018 + sin(t * 1.7 + s * 3) * 0.006),
                    y: CGFloat(cos(t * 0.38 + s) * 0.018 + cos(t * 1.9 + s * 2) * 0.006)
                )
                // Rotate around the glyph's center for a slightly slanted, hand-placed look.
                let dx = p.x - center.x, dy = p.y - center.y
                let rotated = CGPoint(
                    x: center.x + dx * cos(tilt) - dy * sin(tilt) + wobble.x,
                    y: center.y + dx * sin(tilt) + dy * cos(tilt) + wobble.y + lift
                )
                return layout.point(rotated, inCharacterAt: x)
            }
            if points.count == 1 {
                path.addEllipse(in: CGRect(x: points[0].x - layout.unit * 0.06, y: points[0].y - layout.unit * 0.06,
                                           width: layout.unit * 0.12, height: layout.unit * 0.12))
            } else {
                path.addLines(points)
            }
        }
        return path
    }
}

/// A chalk line: solid chalk with slightly ragged edges, a faint dust smear, and irregular
/// grain punched out of it so the board shows through.
struct ChalkStroke: View {
    var path: Path
    var width: CGFloat
    var color: Color

    var body: some View {
        ZStack {
            // A barely-there smear of dust.
            path.stroke(color.opacity(0.05), style: Self.round(width * 1.6))
            // The chalk, laid down twice slightly apart so the edges look ragged, not machined.
            path.stroke(color.opacity(0.8), style: Self.round(width))
            path.stroke(color.opacity(0.45), style: Self.round(width * 0.85))
                .offset(x: width * 0.12, y: width * 0.08)
            // Grain: irregular dash rhythms at different widths knock out specks of chalk.
            grain(dashes: [0.02, 0.19, 0.01, 0.11, 0.03, 0.27, 0.01, 0.15], lineWidth: 0.16, phase: 0.0, offset: (0.14, -0.18), opacity: 0.5)
            grain(dashes: [0.01, 0.23, 0.02, 0.13, 0.01, 0.31], lineWidth: 0.12, phase: 0.37, offset: (-0.2, 0.16), opacity: 0.4)
            grain(dashes: [0.01, 0.09, 0.02, 0.17, 0.01, 0.07], lineWidth: 0.1, phase: 0.61, offset: (0.04, 0.3), opacity: 0.35)
            grain(dashes: [0.02, 0.14, 0.01, 0.21], lineWidth: 0.12, phase: 0.83, offset: (-0.05, -0.32), opacity: 0.4)
        }
        .compositingGroup()
    }

    private func grain(dashes: [CGFloat], lineWidth: CGFloat, phase: CGFloat, offset: (CGFloat, CGFloat), opacity: Double) -> some View {
        path.stroke(.black.opacity(opacity), style: StrokeStyle(
            lineWidth: width * lineWidth, lineCap: .round,
            dash: dashes.map { $0 * width * 2.5 }, dashPhase: phase * width * 2.5
        ))
        .offset(x: width * offset.0, y: width * offset.1)
        .blendMode(.destinationOut)
    }

    private static func round(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

/// A hand-drawn chalk bar: a firm line for the charge, a faint sketch for the rest.
struct ChalkMeter: View {
    var level: Double
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.height * 0.45, proxy.size.width * 0.06)
            let y = proxy.size.height / 2
            let start = CGPoint(x: width, y: y)
            let end = CGPoint(x: proxy.size.width - width, y: y)
            let split = CGPoint(x: start.x + (end.x - start.x) * min(max(level, 0), 1), y: y + width * 0.15)
            ZStack {
                ChalkStroke(path: Path { $0.move(to: split); $0.addLine(to: end) }, width: width * 0.5, color: color.opacity(0.35))
                if level > 0 {
                    ChalkStroke(path: Path { $0.move(to: start); $0.addLine(to: split) }, width: width, color: color)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Segments

/// A seven-segment display with slanted, beveled segments; unlit segments stay faintly visible.
struct SegmentText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool
    var lightweight = false

    var body: some View {
        GlyphCanvas(text: text) { layout in
            let pieces = Self.pieces(layout)
            let width = layout.unit * 0.15 * style.thickness.multiplier
            let bloom = style.bloom.multiplier
            let combined = lightweight && style.isUniform
            ZStack {
                // One shape per character, or one for the whole number (much faster in widgets).
                ForEach(combined ? [0] : Array(layout.placements.indices), id: \.self) { index in
                    let members = combined ? pieces : pieces.filter { $0.character == index }
                    let tint = monochrome ? .white : style.tubeColor(index: index, readout: color)
                    let lit = Self.joined(members.filter(\.isLit))

                    ZStack {
                        Self.joined(members.filter { !$0.isLit })
                            .stroke(tint.opacity(monochrome ? 0.12 : 0.1), style: Self.segmentStroke(width))
                        if bloom > 0 {
                            glow(lit, tint, width: width, bloom: bloom)
                        }
                        lit.stroke(tint, style: Self.segmentStroke(width))
                        lit.stroke(tint.mix(with: .white, by: 0.5).opacity(0.6), style: Self.segmentStroke(width * 0.3))
                    }
                }
            }
        }
    }

    /// Glow around lit segments: a blur in the app; in widgets a wide translucent stroke,
    /// which reads as glow without the cost of a blur.
    @ViewBuilder
    private func glow(_ path: some Shape, _ tint: Color, width: CGFloat, bloom: Double) -> some View {
        if lightweight {
            path.stroke(tint.opacity(0.3 * bloom), style: Self.segmentStroke(width * (1.3 + bloom)))
        } else {
            path.stroke(tint, style: Self.segmentStroke(width * 1.6))
                .blur(radius: width * bloom)
                .opacity(0.75 * bloom)
        }
    }

    /// One segment placed in the view, and which character it belongs to.
    private struct Piece {
        var path: Path
        var isLit: Bool
        var character: Int
    }

    private static func pieces(_ layout: NeonLayout) -> [Piece] {
        layout.placements.enumerated().flatMap { index, placement in
            Segments.shapes(for: placement.character).map { segment in
                Piece(path: Self.path(segment.line, at: placement.x, layout: layout), isLit: segment.isLit, character: index)
            }
        }
    }

    private static func joined(_ pieces: [Piece]) -> Path {
        pieces.reduce(into: Path()) { $0.addPath($1.path) }
    }

    /// Butt-capped strokes with a slight italic slant, so segments meet with visible gaps.
    private static func path(_ line: (CGPoint, CGPoint), at x: CGFloat, layout: NeonLayout) -> Path {
        func slanted(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x + (NeonGlyphs.height - p.y) * 0.07, y: p.y)
        }
        var path = Path()
        path.move(to: layout.point(slanted(line.0), inCharacterAt: x))
        path.addLine(to: layout.point(slanted(line.1), inCharacterAt: x))
        return path
    }

    private static func segmentStroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

/// Seven-segment geometry and the segments each character lights.
private enum Segments {
    struct Segment {
        var line: (CGPoint, CGPoint)
        var isLit: Bool
    }

    // Segment centerlines in the glyph box, shortened at the ends to leave gaps.
    private static let a = (CGPoint(x: 0.24, y: 0.1), CGPoint(x: 0.76, y: 0.1))
    private static let b = (CGPoint(x: 0.88, y: 0.22), CGPoint(x: 0.88, y: 0.68))
    private static let c = (CGPoint(x: 0.88, y: 0.92), CGPoint(x: 0.88, y: 1.38))
    private static let d = (CGPoint(x: 0.24, y: 1.5), CGPoint(x: 0.76, y: 1.5))
    private static let e = (CGPoint(x: 0.12, y: 0.92), CGPoint(x: 0.12, y: 1.38))
    private static let f = (CGPoint(x: 0.12, y: 0.22), CGPoint(x: 0.12, y: 0.68))
    private static let g = (CGPoint(x: 0.24, y: 0.8), CGPoint(x: 0.76, y: 0.8))

    private static let digitSegments: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g"
    ]

    static func shapes(for character: Character) -> [Segment] {
        switch character {
        case ":":
            return [
                Segment(line: (CGPoint(x: 0.15, y: 0.52), CGPoint(x: 0.15, y: 0.58)), isLit: true),
                Segment(line: (CGPoint(x: 0.15, y: 1.02), CGPoint(x: 0.15, y: 1.08)), isLit: true)
            ]
        case "°":
            // A small four-segment box in the top half.
            let box = [
                (CGPoint(x: 0.12, y: 0.1), CGPoint(x: 0.42, y: 0.1)),
                (CGPoint(x: 0.47, y: 0.16), CGPoint(x: 0.47, y: 0.44)),
                (CGPoint(x: 0.12, y: 0.5), CGPoint(x: 0.42, y: 0.5)),
                (CGPoint(x: 0.07, y: 0.16), CGPoint(x: 0.07, y: 0.44))
            ]
            return box.map { Segment(line: $0, isLit: true) }
        case "%":
            let lines = [
                (CGPoint(x: 0.12, y: 0.12), CGPoint(x: 0.4, y: 0.12)), (CGPoint(x: 0.12, y: 0.5), CGPoint(x: 0.4, y: 0.5)),
                (CGPoint(x: 0.07, y: 0.17), CGPoint(x: 0.07, y: 0.45)), (CGPoint(x: 0.45, y: 0.17), CGPoint(x: 0.45, y: 0.45)),
                (CGPoint(x: 0.95, y: 0.12), CGPoint(x: 0.2, y: 1.48)),
                (CGPoint(x: 0.72, y: 1.1), CGPoint(x: 1.0, y: 1.1)), (CGPoint(x: 0.72, y: 1.48), CGPoint(x: 1.0, y: 1.48)),
                (CGPoint(x: 0.67, y: 1.15), CGPoint(x: 0.67, y: 1.43)), (CGPoint(x: 1.05, y: 1.15), CGPoint(x: 1.05, y: 1.43))
            ]
            return lines.map { Segment(line: $0, isLit: true) }
        default:
            guard let on = digitSegments[character] else { return [] }
            let all: [(Character, (CGPoint, CGPoint))] = [("a", a), ("b", b), ("c", c), ("d", d), ("e", e), ("f", f), ("g", g)]
            return all.map { Segment(line: $0.1, isLit: on.contains($0.0)) }
        }
    }
}

// MARK: - Dot Matrix

/// A 5 × 7 board of round lights; unlit dots stay faintly visible.
struct DotMatrixText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool
    var lightweight = false

    var body: some View {
        GlyphCanvas(text: text) { layout in
            let dots = Self.dots(for: layout)
            // Dots sit 0.2 apart, so they're capped just short of touching.
            let radius = layout.unit * min(0.085 * style.thickness.multiplier, 0.095)
            let bloom = style.bloom.multiplier
            let combined = lightweight && style.isUniform
            let tube = monochrome ? .white : style.tubeColor(index: 0, readout: color)
            ZStack {
                // Unlit dots: one shape for the whole board.
                Self.shape(dots.filter { !$0.isLit }, radius: radius)
                    .fill(tube.opacity(0.09))

                // Lit dots: one shape (and at most one glow) per character, or one for the whole number.
                ForEach(combined ? [0] : Array(layout.placements.indices), id: \.self) { index in
                    let tint = monochrome ? .white : style.tubeColor(index: index, readout: color)
                    let lit = dots.filter { $0.isLit && (combined || $0.character == index) }
                    ZStack {
                        if bloom > 0 {
                            glow(lit, tint, radius: radius, bloom: bloom)
                        }
                        Self.shape(lit, radius: radius).fill(tint)
                    }
                }
            }
        }
    }

    /// Glow around lit dots: a blur in the app; in widgets slightly larger translucent dots,
    /// which read as glow without the cost of a blur.
    @ViewBuilder
    private func glow(_ dots: [Dot], _ tint: Color, radius: CGFloat, bloom: Double) -> some View {
        if lightweight {
            Self.shape(dots, radius: radius * (1.3 + 0.6 * bloom)).fill(tint.opacity(0.3 * bloom))
        } else {
            Self.shape(dots, radius: radius).fill(tint).blur(radius: radius * 1.3 * bloom).opacity(0.9 * bloom)
        }
    }

    private static func shape(_ dots: [Dot], radius: CGFloat) -> Path {
        dots.reduce(into: Path()) { path, dot in
            path.addEllipse(in: CGRect(x: dot.center.x - radius, y: dot.center.y - radius, width: radius * 2, height: radius * 2))
        }
    }

    struct Dot {
        var center: CGPoint
        var isLit: Bool
        var character: Int
    }

    static func dots(for layout: NeonLayout) -> [Dot] {
        var result: [Dot] = []
        for (index, placement) in layout.placements.enumerated() {
            let rows = MatrixFont.rows(for: placement.character)
            for (row, line) in rows.enumerated() {
                for (column, bit) in line.enumerated() {
                    let p = CGPoint(x: 0.1 + CGFloat(column) * 0.2, y: 0.2 + CGFloat(row) * 0.2)
                    let center = layout.point(p, inCharacterAt: placement.x)
                    result.append(Dot(center: center, isLit: bit == "#", character: index))
                }
            }
        }
        return result
    }
}

/// Original 5 × 7 bitmaps ("#" = lit) for the characters BigWidget shows.
private enum MatrixFont {
    static func rows(for character: Character) -> [String] {
        switch character {
        case "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."]
        case "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."]
        case "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"]
        case "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."]
        case "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."]
        case "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."]
        case "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."]
        case "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."]
        case "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."]
        case "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."]
        case ":": [".", ".", "#", ".", "#", ".", "."]
        case "-": ["....", "....", "....", "####", "....", "....", "...."]
        case "°": [".#.", "#.#", ".#.", "...", "...", "...", "..."]
        case "%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"]
        default: []
        }
    }
}

// MARK: - Flip

/// A mechanical split-flap display, like an old alarm clock or an airport departure board: each
/// character sits on its own dark card with a center crease and a soft embossed sheen.
struct FlipText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool

    var body: some View {
        GlyphCanvas(text: text) { layout in
            ZStack {
                ForEach(layout.placements.indices, id: \.self) { index in
                    let placement = layout.placements[index]
                    let width = NeonGlyphs.advance(placement.character) * layout.unit
                    FlipCard(
                        character: placement.character,
                        tint: monochrome ? .white : style.tubeColor(index: index, readout: color)
                    )
                    .frame(width: width * 0.88, height: layout.size.height)
                    .position(x: (placement.x + NeonGlyphs.advance(placement.character) / 2) * layout.unit, y: layout.size.height / 2)
                }
            }
        }
    }
}

/// One split-flap card: a dark rounded tile, an embossed gradient, a center crease, and a bold
/// character.
private struct FlipCard: View {
    var character: Character
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let corner = min(w, h) * 0.12
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color(white: 0.09))
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.1), .clear, .black.opacity(0.35)],
                        startPoint: .top, endPoint: .bottom
                    ))
                Text(String(character))
                    .font(.system(size: h * 0.74, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                // The flap crease, dead center.
                Rectangle().fill(Color.black.opacity(0.7)).frame(height: max(1, h * 0.012))
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.7), lineWidth: 1)
            )
        }
    }
}

// MARK: - Analog

/// Dispatches by what the text looks like, since `DisplayText` only knows the formatted string, not
/// which readout it came from: a clock face for "h:mm", a radial gauge for a percentage or a
/// temperature, and plain digits for anything else (Date's day number has no analog form).
struct AnalogDisplay: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool

    var body: some View {
        if text.contains(":") {
            AnalogClockFace(text: text, color: color, style: style, monochrome: monochrome)
        } else if text.hasSuffix("%") {
            AnalogGauge(text: text, color: color, style: style, monochrome: monochrome, kind: .battery)
        } else if text.hasSuffix("°") {
            AnalogGauge(text: text, color: color, style: style, monochrome: monochrome, kind: .weather)
        } else {
            PlainText(text: text, color: color, style: style, monochrome: monochrome)
        }
    }
}

/// A round clock face with hour and minute hands, for the Time readout under Analog.
private struct AnalogClockFace: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let tint = monochrome ? Color.white : style.tubeColor(index: 0, readout: color)
            let (hour, minute) = Self.parse(text)
            ZStack {
                Circle().strokeBorder(tint.opacity(0.5), lineWidth: size * 0.025)
                ForEach(0..<12, id: \.self) { tick in
                    Capsule()
                        .fill(tint.opacity(tick % 3 == 0 ? 0.9 : 0.4))
                        .frame(width: tick % 3 == 0 ? size * 0.025 : size * 0.014, height: tick % 3 == 0 ? size * 0.09 : size * 0.05)
                        .offset(y: -size * 0.42)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }
                Capsule().fill(tint) // Hour hand.
                    .frame(width: size * 0.035, height: size * 0.26)
                    .offset(y: -size * 0.13)
                    .rotationEffect(.degrees(Double(hour % 12) * 30 + Double(minute) * 0.5))
                Capsule().fill(tint) // Minute hand.
                    .frame(width: size * 0.028, height: size * 0.38)
                    .offset(y: -size * 0.19)
                    .rotationEffect(.degrees(Double(minute) * 6))
                Circle().fill(tint).frame(width: size * 0.06, height: size * 0.06)
            }
            .shadow(color: tint.opacity(style.bloom.multiplier * 0.8), radius: size * 0.03 * style.bloom.multiplier)
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// Reads a formatted clock string like "4:42" or "16:07".
    private static func parse(_ text: String) -> (Int, Int) {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0].trimmingCharacters(in: .whitespaces)), let m = Int(parts[1])
        else { return (0, 0) }
        return (h, m)
    }
}

/// A 270° radial gauge (like a car's fuel gauge), for Battery and Weather under Analog.
private struct AnalogGauge: View {
    enum Kind { case battery, weather }

    let text: String
    var color: Color
    var style: NeonStyle
    var monochrome: Bool
    var kind: Kind

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height * 1.3)
            let tint = monochrome ? Color.white : style.tubeColor(index: 0, readout: color)
            let fraction = Self.fraction(text, kind: kind)
            ZStack {
                GaugeArc(end: 1)
                    .stroke(tint.opacity(0.22), style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                GaugeArc(end: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                    .shadow(color: tint.opacity(style.bloom.multiplier), radius: size * 0.03 * style.bloom.multiplier)
                Text(text)
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .offset(y: size * 0.1)
            }
            .frame(width: size, height: size * 0.78)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// 0...1 across the gauge's sweep. Weather assumes a generous -20°...120° range so it reads
    /// sensibly in either Fahrenheit or Celsius, just not calibrated to either specifically.
    private static func fraction(_ text: String, kind: Kind) -> Double {
        guard let value = Double(text.filter { $0.isNumber || $0 == "-" }) else { return 0 }
        switch kind {
        case .battery: return min(max(value / 100, 0), 1)
        case .weather: return min(max((value + 20) / 140, 0), 1)
        }
    }
}

/// A 270° arc from the bottom-left, used as a gauge sweep: `end` of 0 is empty, 1 is full.
private struct GaugeArc: Shape {
    var end: Double

    var animatableData: Double {
        get { end }
        set { end = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(
            center: center, radius: radius,
            startAngle: .degrees(135), endAngle: .degrees(135 + 270 * end), clockwise: false
        )
        return path
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(NumberStyle.allCases, id: \.self) { numbers in
                DisplayText(text: "12:34", style: NeonStyle(scheme: .classic, numbers: numbers, bloom: .soft))
                    .frame(height: 120)
            }
        }
        .padding()
    }
    .background(.black)
}

#Preview("New styles") {
    VStack(spacing: 10) {
        DisplayText(text: "12:34", style: NeonStyle(scheme: .gold, numbers: .script))
        DisplayText(text: "82%", style: NeonStyle(scheme: .christmas, numbers: .calligraphy))
        DisplayText(text: "4:42", style: NeonStyle(scheme: .patriotic, numbers: .flip))
        HStack(spacing: 10) {
            DisplayText(text: "4:42", style: NeonStyle(scheme: .halloween, numbers: .analog))
            DisplayText(text: "82%", style: NeonStyle(scheme: .teal, numbers: .analog))
            DisplayText(text: "72°", style: NeonStyle(scheme: .valentine, numbers: .analog))
        }
    }
    .padding()
    .frame(height: 650)
    .background(.black)
}
