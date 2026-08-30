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
    @State private var foregroundToken = 0

    @StateObject private var nearby = NearbyGamesService()
    @ObservedObject private var push = PushNotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

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
                pushToken: push.deviceToken,
                foregroundToken: foregroundToken,
                requestedGameCode: push.requestedGameCode,
                onLoadingChanged: { loading in
                    isLoading = loading
                    if loading { failure = nil }
                },
                onFailure: { failure = $0 },
                onGameContext: handleGameContext,
                onRequestedGameHandled: { push.requestedGameCode = nil }
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
        .onChange(of: scenePhase) { _, phase in
            // iOS freezes the web view's timers and sockets in the background,
            // so returning is the client's cue to check a connection that may
            // have died without either side noticing.
            if phase == .active { foregroundToken += 1 }
        }
        .onOpenURL { url in
            // A shared invite opened from Messages or Safari. The client is
            // already running, so hand it the code rather than reloading.
            if let code = GameWebURL.sharedGameCode(in: url) {
                push.requestedGameCode = code
            }
        }
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
