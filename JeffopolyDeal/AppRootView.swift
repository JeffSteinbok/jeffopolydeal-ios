import SwiftUI

/// The app is a shell around the shared React client, which owns the entire
/// player experience from the start page through gameplay. Everything native
/// lives inside `GameWebHostView`.
struct AppRootView: View {
    var body: some View {
        GameWebHostView()
    }
}

#Preview {
    AppRootView()
}
