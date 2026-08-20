import SwiftUI

/// Direct port of src/web/pages/gamePage/components/RentIcon.tsx.
/// The "d" strings below are copied verbatim from the original SVG paths;
/// SVGPathShape replays them so the tilted-house geometry matches exactly.
struct RentIconView: View {
    var count: Int
    var color: Color = Color(hex: "#ed2024")

    private static let stroke = Color(hex: "#231f20")
    private static let strokeWidth: CGFloat = 0.75
    private static let vbW: CGFloat = 28.65
    private static let vbH: CGFloat = 24.55

    var body: some View {
        let c = max(1, min(4, count))
        GeometryReader { geo in
            ZStack {
                if c >= 4 { house4 }
                if c >= 3 { house3 }
                if c >= 2 { house2 }
                house1
                Text("\(c)")
                    .font(.interRegular(12 * geo.size.height / Self.vbH))
                    .foregroundColor(Self.stroke)
                    .position(numberPosition(for: c, in: geo.size))
            }
        }
    }

    private func numberPosition(for c: Int, in size: CGSize) -> CGPoint {
        // translate(x, y) targets from the original <text transform>, treated as the
        // baseline anchor; nudged up/left since SwiftUI positions by glyph center.
        let translates: [CGPoint] = [
            CGPoint(x: 17.57, y: 18.68),
            CGPoint(x: 17.63, y: 18.42),
            CGPoint(x: 17.47, y: 18.77),
            CGPoint(x: 17.48, y: 18.11),
        ]
        let t = translates[c - 1]
        let fx = (t.x + 3) / Self.vbW
        let fy = (t.y - 5) / Self.vbH
        return CGPoint(x: fx * size.width, y: fy * size.height)
    }

    private func shape(_ d: String) -> SVGPathShape {
        SVGPathShape(d: d, viewBoxWidth: Self.vbW, viewBoxHeight: Self.vbH)
    }

    // House 1 — upright rectangle (always the front)
    private var house1: some View {
        ZStack {
            shape("M28.27,5.08v2h-14.8v-2c0-1.51,1.22-2.73,2.72-2.73h9.36c1.5,0,2.72,1.22,2.72,2.73Z")
                .fill(color)
            shape("M28.27,5.08v2h-14.8v-2c0-1.51,1.22-2.73,2.72-2.73h9.36c1.5,0,2.72,1.22,2.72,2.73Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
            shape("M28.27,7.08v13.55c0,1.5-1.22,2.72-2.72,2.72h-9.36c-1.5,0-2.72-1.22-2.72-2.72V7.08h14.8Z")
                .fill(Color.white)
            shape("M28.27,7.08v13.55c0,1.5-1.22,2.72-2.72,2.72h-9.36c-1.5,0-2.72-1.22-2.72-2.72V7.08h14.8Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
        }
    }

    // House 2 — tilted left
    private var house2: some View {
        ZStack {
            shape("M20.87,2.37l.83,1.82-13.47,6.14-.83-1.82c-.63-1.37-.02-2.99,1.34-3.61l8.52-3.88c1.36-.62,2.98-.02,3.61,1.36Z")
                .fill(color)
            shape("M20.87,2.37l.83,1.82-13.47,6.14-.83-1.82c-.63-1.37-.02-2.99,1.34-3.61l8.52-3.88c1.36-.62,2.98-.02,3.61,1.36Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
            shape("M21.7,4.19l5.62,12.33c.62,1.36.02,2.98-1.35,3.6l-8.52,3.88c-1.36.62-2.98.02-3.6-1.35l-5.62-12.33,13.47-6.14Z")
                .fill(Color.white)
            shape("M21.7,4.19l5.62,12.33c.62,1.36.02,2.98-1.35,3.6l-8.52,3.88c-1.36.62-2.98.02-3.6-1.35l-5.62-12.33,13.47-6.14Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
        }
    }

    // House 3 — tilted more
    private var house3: some View {
        ZStack {
            shape("M14.12,2.2l1.37,1.46L4.7,13.78l-1.37-1.46c-1.03-1.1-.98-2.83.12-3.85l6.83-6.4c1.09-1.03,2.82-.97,3.85.13Z")
                .fill(color)
            shape("M14.12,2.2l1.37,1.46L4.7,13.78l-1.37-1.46c-1.03-1.1-.98-2.83.12-3.85l6.83-6.4c1.09-1.03,2.82-.97,3.85.13Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
            shape("M15.49,3.65l9.27,9.88c1.03,1.09.97,2.82-.12,3.84l-6.83,6.4c-1.09,1.03-2.82.97-3.84-.12L4.7,13.78,15.49,3.65Z")
                .fill(Color.white)
            shape("M15.49,3.65l9.27,9.88c1.03,1.09.97,2.82-.12,3.84l-6.83,6.4c-1.09,1.03-2.82.97-3.84-.12L4.7,13.78,15.49,3.65Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
        }
    }

    // House 4 — tilted furthest
    private var house4: some View {
        ZStack {
            shape("M8.08,3.44l1.83.8-5.94,13.56-1.83-.8c-1.38-.61-2.01-2.21-1.41-3.59l3.75-8.57c.6-1.37,2.21-2,3.59-1.4Z")
                .fill(color)
            shape("M8.08,3.44l1.83.8-5.94,13.56-1.83-.8c-1.38-.61-2.01-2.21-1.41-3.59l3.75-8.57c.6-1.37,2.21-2,3.59-1.4Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
            shape("M9.91,4.25l12.41,5.44c1.37.6,2,2.21,1.4,3.58l-3.75,8.57c-.6,1.37-2.21,2-3.58,1.4l-12.41-5.44,5.94-13.56Z")
                .fill(Color.white)
            shape("M9.91,4.25l12.41,5.44c1.37.6,2,2.21,1.4,3.58l-3.75,8.57c-.6,1.37-2.21,2-3.58,1.4l-12.41-5.44,5.94-13.56Z")
                .stroke(Self.stroke, lineWidth: Self.strokeWidth)
        }
    }
}
