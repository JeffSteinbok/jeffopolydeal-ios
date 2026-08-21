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
