import SwiftUI

/// The native shell around the shared React client.
///
/// The client owns the whole player experience — start page, lobby, gameplay,
/// and the SignalR connection. This view owns the window, the loading and error
/// chrome, and the capabilities the web cannot have: local-network discovery,
/// and enough session memory for notifications to route back to a game.
struct GameWebHostView: View {
    @State private var isLoading = true
    @State private var failure: GameWebLoadFailure?
    @State private var reloadToken = 0
    @State private var context: GameBridge.GameContext?

    @StateObject private var nearby = NearbyGamesService()

    private var startURL: URL {
        GameWebURL.start(playerNameHint: DeviceName.guessMyName())
    }

    var body: some View {
        ZStack {
            AppBackground()

            GameWebView(
                entryURL: startURL,
                reloadToken: reloadToken,
                nearbyGames: nearby.nearbyGames,
                onLoadingChanged: { loading in
                    isLoading = loading
                    if loading { failure = nil }
                },
                onFailure: { failure = $0 },
                onGameContext: handleGameContext
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
        .onAppear { nearby.startBrowsing() }
        .onDisappear {
            nearby.stopBrowsing()
            nearby.stopAdvertising()
        }
    }

    /// Discovery is symmetric: a device sitting in a lobby advertises its code,
    /// and a device that is not in one looks for codes to join. The client tells
    /// us which of those we are; it never has to know Multipeer exists.
    private func handleGameContext(_ context: GameBridge.GameContext) {
        self.context = context

        if context.isLobby, let code = context.gameCode {
            nearby.stopBrowsing()
            nearby.startAdvertising(gameCode: code, hostName: context.hostName ?? "Nearby Host")
        } else {
            nearby.stopAdvertising()
            if context.gameCode == nil { nearby.startBrowsing() }
        }

        // Remembered only so a notification tap can route back to this game.
        // Gameplay state stays in the client.
        if let code = context.gameCode, let id = context.playerId {
            SessionStore.saveSession(
                Session(gameCode: code, playerName: context.playerName ?? "", playerId: id)
            )
        } else if context.gameCode == nil {
            SessionStore.clearSession()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Image("TitleImage")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)

            ProgressView()
                .controlSize(.large)
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

            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
