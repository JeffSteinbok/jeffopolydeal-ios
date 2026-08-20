import SwiftUI

/// Minimal SVG path-data ("d" attribute) interpreter, supporting the commands actually
/// used by the game's hand-drawn icons: M/m, L/l, H/h, V/v, C/c, Z/z, with SVG's implicit
/// command-repeat rule. Letting Swift replay the exact "d" strings from RentIcon.tsx (rather
/// than hand-transcribing bezier math) guarantees the geometry matches the original art.

private enum SVGToken {
    case command(Character)
    case number(Double)
}

private func tokenizeSVGPath(_ d: String) -> [SVGToken] {
    var tokens: [SVGToken] = []
    let commandChars = Set("MmLlHhVvCcZz")
    let chars = Array(d)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if c.isWhitespace || c == "," {
            i += 1
            continue
        }
        if commandChars.contains(c) {
            tokens.append(.command(c))
            i += 1
            continue
        }
        var j = i
        if chars[j] == "-" || chars[j] == "+" { j += 1 }
        var sawDot = false
        while j < chars.count && (chars[j].isNumber || (chars[j] == "." && !sawDot)) {
            if chars[j] == "." { sawDot = true }
            j += 1
        }
        if j > i, let val = Double(String(chars[i..<j])) {
            tokens.append(.number(val))
            i = j
        } else {
            i += 1 // skip anything unparseable rather than looping forever
        }
    }
    return tokens
}

struct SVGPathShape: Shape {
    let d: String
    let viewBoxWidth: CGFloat
    let viewBoxHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / viewBoxWidth
        let sy = rect.height / viewBoxHeight
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + CGFloat(x) * sx, y: rect.minY + CGFloat(y) * sy)
        }

        let tokens = tokenizeSVGPath(d)
        var idx = 0
        var cur = (x: 0.0, y: 0.0)
        var start = (x: 0.0, y: 0.0)
        var cmd: Character = "M"

        func nextNumber() -> Double? {
            guard idx < tokens.count, case let .number(v) = tokens[idx] else { return nil }
            idx += 1
            return v
        }

        while idx < tokens.count {
            if case let .command(c) = tokens[idx] {
                cmd = c
                idx += 1
            }
            switch cmd {
            case "M", "m":
                guard let x = nextNumber(), let y = nextNumber() else { idx += 1; continue }
                let nx = cmd == "m" ? cur.x + x : x
                let ny = cmd == "m" ? cur.y + y : y
                cur = (nx, ny); start = cur
                path.move(to: pt(nx, ny))
                cmd = (cmd == "m") ? "l" : "L" // subsequent coordinate pairs are implicit lineto
            case "L", "l":
                guard let x = nextNumber(), let y = nextNumber() else { idx += 1; continue }
                let nx = cmd == "l" ? cur.x + x : x
                let ny = cmd == "l" ? cur.y + y : y
                cur = (nx, ny)
                path.addLine(to: pt(nx, ny))
            case "H", "h":
                guard let x = nextNumber() else { idx += 1; continue }
                cur.x = cmd == "h" ? cur.x + x : x
                path.addLine(to: pt(cur.x, cur.y))
            case "V", "v":
                guard let y = nextNumber() else { idx += 1; continue }
                cur.y = cmd == "v" ? cur.y + y : y
                path.addLine(to: pt(cur.x, cur.y))
            case "C", "c":
                guard let x1 = nextNumber(), let y1 = nextNumber(),
                      let x2 = nextNumber(), let y2 = nextNumber(),
                      let x = nextNumber(), let y = nextNumber() else { idx += 1; continue }
                let isRel = cmd == "c"
                let c1 = isRel ? (cur.x + x1, cur.y + y1) : (x1, y1)
                let c2 = isRel ? (cur.x + x2, cur.y + y2) : (x2, y2)
                let end = isRel ? (cur.x + x, cur.y + y) : (x, y)
                path.addCurve(to: pt(end.0, end.1), control1: pt(c1.0, c1.1), control2: pt(c2.0, c2.1))
                cur = end
            case "Z", "z":
                path.closeSubpath()
                cur = start
            default:
                idx += 1
            }
        }
        return path
    }
}
