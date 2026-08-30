import SwiftUI

/// Matches the web app's global background (src/web/styles/global.css:17):
/// linear-gradient(135deg, #c8e6c9 0%, #e8f5e9 50%, #dcedc8 100%).
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#c8e6c9"), location: 0),
                .init(color: Color(hex: "#e8f5e9"), location: 0.5),
                .init(color: Color(hex: "#dcedc8"), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

extension View {
    func appBackground() -> some View {
        background(AppBackground())
    }
}

extension Color {
    /// Lets the shell's few colours be written the same way the web client's CSS
    /// writes them. Moved here when the duplicated gameplay views were removed.
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}
