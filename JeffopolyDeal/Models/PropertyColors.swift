import SwiftUI

// Mirrors src/web/utilities/PropertyColors.ts

struct PropertyColorInfo {
    let name: String
    let hex: Color
    let textColor: Color
}

let PropertyColorMap: [PropertyColor: PropertyColorInfo] = [
    .brown:     PropertyColorInfo(name: "Brown",      hex: Color(hex: "#6d3b15"), textColor: .white),
    .lightBlue: PropertyColorInfo(name: "Light Blue", hex: Color(hex: "#72c5e8"), textColor: .white),
    .pink:      PropertyColorInfo(name: "Pink",       hex: Color(hex: "#d9308e"), textColor: .white),
    .orange:    PropertyColorInfo(name: "Orange",     hex: Color(hex: "#f58220"), textColor: .white),
    .red:       PropertyColorInfo(name: "Red",        hex: Color(hex: "#e3242b"), textColor: .white),
    .yellow:    PropertyColorInfo(name: "Yellow",     hex: Color(hex: "#feed00"), textColor: .black),
    .green:     PropertyColorInfo(name: "Green",      hex: Color(hex: "#1fb25a"), textColor: .white),
    .darkBlue:  PropertyColorInfo(name: "Dark Blue",  hex: Color(hex: "#0055a5"), textColor: .white),
    .railroad:  PropertyColorInfo(name: "Railroad",   hex: Color(hex: "#1a1a1a"), textColor: .white),
    .utility:   PropertyColorInfo(name: "Utility",    hex: Color(hex: "#b5d99c"), textColor: .black),
]

let PropertyColorOrder: [PropertyColor] = [
    .brown, .lightBlue, .pink, .orange, .red, .yellow, .green, .darkBlue, .railroad, .utility,
]

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
