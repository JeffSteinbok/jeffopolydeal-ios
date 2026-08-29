import SwiftUI

/// Owns app entry: session persistence, playerId, and the switch between the
/// native StartView and the embedded React gameplay client. A saved session on
/// launch means "attempt RejoinGame", the same as a page reload on web.
struct AppRootView: View {
    @State private var gameCode: String?
    @State private var playerName: String = ""
    @State private var isRejoin: Bool = false
    @State private var inGame: Bool = false

    private let playerId = SessionStore.playerId

    var body: some View {
        Group {
            if inGame {
                GameWebHostView(
                    gameCode: gameCode ?? "",
                    playerName: playerName,
                    playerId: playerId,
                    isRejoin: isRejoin,
                    onGameCodeResolved: { code in
                        gameCode = code
                        SessionStore.saveSession(Session(gameCode: code, playerName: playerName, playerId: playerId))
                    },
                    onLeave: handleLeave
                )
            } else {
                StartView(onJoinGame: handleJoin)
            }
        }
        .onAppear {
            if let saved = SessionStore.loadSession() {
                gameCode = saved.gameCode
                playerName = saved.playerName
                isRejoin = true
                inGame = true
            }
        }
    }

    private func handleJoin(_ code: String, _ name: String) {
        gameCode = code
        playerName = name
        isRejoin = false
        inGame = true
        SessionStore.saveSession(Session(gameCode: code, playerName: name, playerId: playerId))
    }

    private func handleLeave() {
        SessionStore.clearSession()
        inGame = false
        gameCode = nil
        isRejoin = false
    }
}

#Preview {
    AppRootView()
}
