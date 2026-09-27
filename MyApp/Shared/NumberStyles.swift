import SwiftUI

// MARK: - Settings

/// How the numbers are drawn. Every style is drawn from shapes defined in this project (no fonts),
/// all sized in the same 1 × 1.6 glyph box so layouts work the same for each.
enum NumberStyle: String, CaseIterable, Codable, Sendable {
    /// Bent glass tubes with light coursing through them.
    case neon
    /// Hand-drawn chalk on a slate chalkboard.
    case chalk
    /// Dashed strokes whose dashes march along the digit.
    case brokenLine
    /// A seven-segment display, with unlit segments faintly visible.
    case segments
    /// A 5 × 7 grid of lights, like a dot-matrix board.
    case dotMatrix

    var title: String {
        switch self {
        case .neon: "Neon"
        case .chalk: "Chalk"
        case .brokenLine: "Broken Line"
        case .segments: "Segments"
        case .dotMatrix: "Dot Matrix"
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
    var phase: Double = 0
    var monochrome = false
    var glidesBetweenSteps = false
    var lightweight = false

    var body: some View {
        switch style.numbers {
        case .neon:
            NeonText(
                text: text, color: color, style: style, phase: phase, monochrome: monochrome,
                glidesBetweenSteps: glidesBetweenSteps, lightweight: lightweight
            )
        case .chalk:
            ChalkText(text: text, color: color, style: style, phase: phase, monochrome: monochrome, glidesBetweenSteps: glidesBetweenSteps)
        case .brokenLine:
            BrokenLineText(text: text, color: color, style: style, phase: phase, monochrome: monochrome, glidesBetweenSteps: glidesBetweenSteps)
        case .segments:
            SegmentText(text: text, color: color, style: style, phase: phase, monochrome: monochrome, glidesBetweenSteps: glidesBetweenSteps)
        case .dotMatrix:
            DotMatrixText(text: text, color: color, style: style, phase: phase, monochrome: monochrome, glidesBetweenSteps: glidesBetweenSteps)
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

private func glideAnimation(_ glides: Bool) -> Animation? {
    glides ? .easeInOut(duration: 1.9) : nil
}

/// The battery meter drawn to match the number style: a chalk line for Chalk, a neon tube otherwise.
struct DisplayMeter: View {
    var level: Double
    var color: Color
    var isCharging: Bool
    var style = NeonStyle()
    var phase: Double = 0
    var monochrome = false
    var glidesBetweenSteps = false
    var lightweight = false

    var body: some View {
        if style.numbers == .chalk {
            ChalkMeter(level: level, isCharging: isCharging, color: monochrome ? .white : Color(white: 0.96))
        } else {
            NeonMeter(
                level: level, color: color, isCharging: isCharging, style: style, phase: phase,
                monochrome: monochrome, glidesBetweenSteps: glidesBetweenSteps, lightweight: lightweight
            )
        }
    }
}

// MARK: - Chalk

/// Hand-lettered chalk: each stroke wobbles a little, each character tilts and sits slightly off the
/// baseline, and a speckled texture lets the board show through like real chalk.
struct ChalkText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var phase: Double
    var monochrome: Bool
    var glidesBetweenSteps: Bool

    var body: some View {
        GlyphCanvas(text: text) { layout in
            ZStack {
                ForEach(layout.placements.indices, id: \.self) { index in
                    let placement = layout.placements[index]
                    let path = Self.handDrawnPath(placement.character, at: placement.x, seed: index, layout: layout)
                    let chalk = chalkColor(index: index)
                    ChalkStroke(path: path, width: layout.unit * 0.14, color: chalk)
                        .opacity(0.35 + 0.65 * style.brightness(index: index, phase: phase))
                }
            }
            .animation(glideAnimation(glidesBetweenSteps), value: phase)
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
    var isCharging: Bool
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
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: width * 2.2, weight: .black))
                        .foregroundStyle(color)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A dark slate chalkboard with soft eraser smudges.
struct ChalkboardBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.13, green: 0.21, blue: 0.17), Color(red: 0.08, green: 0.14, blue: 0.11)],
                    startPoint: .top, endPoint: .bottom
                )
                // Old eraser marks.
                ForEach(0..<4, id: \.self) { i in
                    let d = Double(i)
                    Ellipse()
                        .fill(.white.opacity(0.035))
                        .frame(width: size.width * (0.5 + 0.1 * d), height: size.height * 0.22)
                        .rotationEffect(.degrees(-8 + d * 5))
                        .position(x: size.width * (0.3 + 0.18 * d), y: size.height * (0.25 + 0.17 * d))
                        .blur(radius: size.height * 0.05)
                }
                RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center,
                               startRadius: min(size.width, size.height) * 0.3, endRadius: max(size.width, size.height) * 0.8)
            }
        }
    }
}

// MARK: - Broken Line

/// The digits drawn as dashed lines; the dashes march along the strokes as the light moves.
struct BrokenLineText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var phase: Double
    var monochrome: Bool
    var glidesBetweenSteps: Bool

    var body: some View {
        GlyphCanvas(text: text) { layout in
            ZStack {
                ForEach(layout.glyphs.indices, id: \.self) { index in
                    let tint = monochrome ? Color.white : style.tubeColor(index: index, readout: color)
                    let width = layout.unit * 0.13
                    // Dots (like the colon) are too short to hold a dash, so they draw solid.
                    let isDot = layout.glyphs[index].length < layout.unit * 0.5
                    let dash = MarchingDashes(path: layout.glyphs[index].path, width: width, phase: phase * layout.unit * 12, solid: isDot)
                    ZStack {
                        if style.bloom.multiplier > 0 {
                            dash.fill(tint).blur(radius: width * 0.9 * style.bloom.multiplier)
                                .opacity(0.8 * style.bloom.multiplier)
                        }
                        dash.fill(tint)
                        // Bright center line on each dash.
                        MarchingDashes(path: layout.glyphs[index].path, width: width * 0.35, phase: phase * layout.unit * 12, solid: isDot)
                            .fill(tint.mix(with: .white, by: 0.55))
                    }
                    .opacity(0.35 + 0.65 * style.brightness(index: index, phase: phase))
                }
            }
            .animation(glideAnimation(glidesBetweenSteps), value: phase)
        }
    }
}

/// Dashes along a path, with an animatable phase so they glide instead of jumping.
private struct MarchingDashes: Shape {
    var path: Path
    var width: CGFloat
    var phase: Double
    var solid = false

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        path.strokedPath(StrokeStyle(
            lineWidth: width, lineCap: .round, lineJoin: .round,
            dash: solid ? [] : [width * 1.1, width * 1.3], dashPhase: -phase
        ))
    }
}

// MARK: - Segments

/// A seven-segment display with slanted, beveled segments; unlit segments stay faintly visible.
struct SegmentText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var phase: Double
    var monochrome: Bool
    var glidesBetweenSteps: Bool

    var body: some View {
        GlyphCanvas(text: text) { layout in
            ZStack {
                ForEach(layout.placements.indices, id: \.self) { index in
                    let placement = layout.placements[index]
                    let tint = monochrome ? Color.white : style.tubeColor(index: index, readout: color)
                    let segments = Segments.shapes(for: placement.character)
                    let lit = segments.filter(\.isLit).reduce(into: Path()) { $0.addPath(Self.path($1.line, at: placement.x, layout: layout)) }
                    let unlit = segments.filter { !$0.isLit }.reduce(into: Path()) { $0.addPath(Self.path($1.line, at: placement.x, layout: layout)) }
                    let width = layout.unit * 0.15
                    let brightness = style.brightness(index: index, phase: phase)

                    ZStack {
                        unlit.stroke(tint.opacity(monochrome ? 0.12 : 0.1), style: Self.segmentStroke(width))
                        if style.bloom.multiplier > 0 {
                            lit.stroke(tint, style: Self.segmentStroke(width * 1.6))
                                .blur(radius: width * style.bloom.multiplier)
                                .opacity(0.75 * style.bloom.multiplier * brightness)
                        }
                        lit.stroke(tint.opacity(0.35 + 0.65 * brightness), style: Self.segmentStroke(width))
                        lit.stroke(tint.mix(with: .white, by: 0.5).opacity(0.6 * brightness), style: Self.segmentStroke(width * 0.3))
                    }
                }
            }
            .animation(glideAnimation(glidesBetweenSteps), value: phase)
        }
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

/// A 5 × 7 board of round lights; unlit dots stay faintly visible and, with moving effects,
/// a band of colored light sweeps across the board.
struct DotMatrixText: View {
    let text: String
    var color: Color
    var style: NeonStyle
    var phase: Double
    var monochrome: Bool
    var glidesBetweenSteps: Bool

    var body: some View {
        GlyphCanvas(text: text) { layout in
            let dots = Self.dots(for: layout)
            let radius = layout.unit * 0.085
            let pulses = monochrome ? [] : style.pulseColors(for: style.tubeColor(index: 0, readout: color))
            let bloom = style.bloom.multiplier
            ZStack {
                // Unlit dots: one shape for the whole board.
                Self.shape(dots.filter { !$0.isLit }, radius: radius)
                    .fill((monochrome ? Color.white : style.tubeColor(index: 0, readout: color)).opacity(0.09))

                // Lit dots, one shape (and at most one glow) per character.
                ForEach(layout.placements.indices, id: \.self) { index in
                    let tint = monochrome ? Color.white : style.tubeColor(index: index, readout: color)
                    let lit = Self.shape(dots.filter { $0.isLit && $0.character == index }, radius: radius)
                    let brightness = style.brightness(index: index, phase: phase)
                    ZStack {
                        if bloom > 0 {
                            lit.fill(tint).blur(radius: radius * 1.3 * bloom).opacity(0.9 * bloom)
                        }
                        lit.fill(tint)
                    }
                    .opacity(0.35 + 0.65 * brightness)
                }

                // The moving band of pulse color.
                if let band = Self.sweep(phase: phase, colors: pulses) {
                    let swept = Self.shape(dots.filter { $0.isLit && band.contains($0.x) }, radius: radius * 1.05)
                    ZStack {
                        if bloom > 0 {
                            swept.fill(band.color).blur(radius: radius * 1.3 * bloom).opacity(0.9 * bloom)
                        }
                        swept.fill(band.color.mix(with: .white, by: 0.25))
                    }
                }
            }
            .animation(glideAnimation(glidesBetweenSteps), value: phase)
        }
    }

    private static func shape(_ dots: [Dot], radius: CGFloat) -> Path {
        dots.reduce(into: Path()) { path, dot in
            path.addEllipse(in: CGRect(x: dot.center.x - radius, y: dot.center.y - radius, width: radius * 2, height: radius * 2))
        }
    }

    /// Where the band of pulse color is (as a 0...1 range across the text), and its color.
    private static func sweep(phase: Double, colors: [Color]) -> (color: Color, contains: (CGFloat) -> Bool)? {
        guard !colors.isEmpty else { return nil }
        var position = phase.truncatingRemainder(dividingBy: 1)
        if position < 0 { position += 1 }
        let color = colors[Int(abs(phase.rounded(.down))) % colors.count]
        return (color, { x in
            let distance = abs(Double(x) - position)
            return min(distance, 1 - distance) < 0.09
        })
    }

    struct Dot {
        var center: CGPoint
        var isLit: Bool
        /// 0...1 across the whole text, for the sweep.
        var x: CGFloat
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
                    result.append(Dot(center: center, isLit: bit == "#", x: center.x / max(layout.size.width, 1), character: index))
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

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(NumberStyle.allCases, id: \.self) { numbers in
                DisplayText(
                    text: "12:34",
                    style: NeonStyle(scheme: .classic, effect: .coursing, numbers: numbers, bloom: .soft),
                    phase: 0.3
                )
                .frame(height: 120)
                .background { if numbers == .chalk { ChalkboardBackground() } }
            }
        }
        .padding()
    }
    .background(.black)
}
