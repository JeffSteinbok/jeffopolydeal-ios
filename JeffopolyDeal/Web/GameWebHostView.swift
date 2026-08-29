import SwiftUI

/// The native shell around the shared React gameplay client: it owns the window,
/// the loading/error/retry chrome, and the trip back to StartView. Gameplay
/// itself — rendering, interaction, and the SignalR connection — lives in the
/// web client, so nothing here interprets game state.
struct GameWebHostView: View {
    let gameCode: String
    let playerName: String
    let playerId: String
    let isRejoin: Bool
    var onGameCodeResolved: ((String) -> Void)? = nil
    let onLeave: () -> Void

    @State private var isLoading = true
    @State private var failure: GameWebLoadFailure?
    @State private var reloadToken = 0

    private var entryURL: URL {
        GameWebURL.entry(
            gameCode: gameCode,
            playerName: playerName,
            playerId: playerId,
            isRejoin: isRejoin
        )
    }

    var body: some View {
        ZStack {
            AppBackground()

            GameWebView(
                entryURL: entryURL,
                reloadToken: reloadToken,
                onLoadingChanged: { loading in
                    isLoading = loading
                    if loading { failure = nil }
                },
                onFailure: { failure = $0 },
                onGameCodeResolved: { onGameCodeResolved?($0) },
                onExit: onLeave
            )
            .ignoresSafeArea()
            .opacity(failure == nil ? 1 : 0)

            if let failure {
                failureView(failure)
            } else if isLoading {
                loadingView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: failure)
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Image("TitleImage")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)

            ProgressView()
                .controlSize(.large)

            Text(isRejoin ? "Rejoining your game…" : "Connecting…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .transition(.opacity)
    }

    private func failureView(_ failure: GameWebLoadFailure) -> some View {
        VStack(spacing: 20) {
            Image("TitleImage")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)

            VStack(spacing: 8) {
                Text(failure.title)
                    .font(.title3.bold())
                Text(failure.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Leave Game", role: .destructive, action: onLeave)
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .transition(.opacity)
    }

    private func retry() {
        failure = nil
        isLoading = true
        reloadToken += 1
    }
}
