import SwiftUI

/// Mirrors src/web/pages/gamePage/GamePage.tsx. Phase 1 scope: connection
/// lifecycle (create/join/rejoin) + full Lobby-phase rendering. Draw/Play/
/// Discard/AwaitingResponse/GameOver are stubbed pending later phases.
struct GameView: View {
    let gameCode: String
    let playerName: String
    let playerId: String
    let isRejoin: Bool
    var onGameCodeResolved: ((String) -> Void)? = nil
    let onLeave: () -> Void

    @StateObject private var hub = GameHubClient()
    @State private var error: String?
    @State private var showLeaveConfirm = false

    var body: some View {
        Group {
            if let error {
                connectionErrorView(error)
            } else if let state = hub.state {
                content(for: state)
            } else {
                ProgressView("Connecting…")
            }
        }
        .task { await connect() }
    }

    // MARK: - Connection lifecycle (mirrors GamePage.tsx:84-132)

    private func connect() async {
        do {
            try await hub.start()

            if isRejoin, !gameCode.isEmpty {
                let success = try await hub.rejoinGame(gameCode: gameCode, playerName: playerName, playerId: playerId)
                if !success {
                    onLeave()
                    return
                }
            } else if gameCode.isEmpty {
                let newCode = try await hub.createGame()
                try await hub.joinGame(gameCode: newCode, playerName: playerName, playerId: playerId)
                onGameCodeResolved?(newCode)
            } else {
                try await hub.joinGame(gameCode: gameCode, playerName: playerName, playerId: playerId)
            }
        } catch {
            self.error = "Failed to connect to game server."
        }
    }

    private func connectionErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
            Button("Leave", action: onLeave)
        }
        .padding()
    }

    // MARK: - Phase routing

    @ViewBuilder
    private func content(for state: GameState) -> some View {
        switch state.phase {
        case .lobby:
            LobbyView(
                state: state,
                myPlayerId: playerId,
                onAddBot: { try? await hub.addBotPlayer(gameCode: state.gameCode) },
                onStartGame: { minPlayers in
                    try? await hub.startGame(gameCode: state.gameCode, allowSinglePlayer: minPlayers == 1)
                },
                onLeave: { showLeaveConfirm = true }
            )
            .confirmationDialog(
                "Leave this game? This will end the game for all players.",
                isPresented: $showLeaveConfirm,
                titleVisibility: .visible
            ) {
                Button("Leave Game", role: .destructive, action: onLeave)
                Button("Cancel", role: .cancel) {}
            }
        case .draw, .play, .awaitingResponse, .discard, .gameOver:
            // TODO(Phase 2+): board, hand, action/discard sheets, game-over screen.
            VStack(spacing: 12) {
                Text("Phase: \(state.phase.rawValue)")
                Text("Board UI coming in a later phase.")
                    .foregroundStyle(.secondary)
                Button("Leave", action: onLeave)
            }
        }
    }
}

/// Mirrors GamePage.tsx:261-325 (the Lobby-phase render).
private struct LobbyView: View {
    let state: GameState
    let myPlayerId: String
    let onAddBot: () async -> Void
    let onStartGame: (_ minPlayers: Int) async -> Void
    let onLeave: () -> Void

    private var isCreator: Bool { state.players.first?.playerId == myPlayerId }
    private var connectedCount: Int { state.players.filter(\.isConnected).count }
    private var canStart: Bool { isCreator || (state.players.first.map { !$0.isConnected } ?? false) }
    private let minPlayers = 2

    var body: some View {
        VStack(spacing: 20) {
            Image("TitleImage")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)

            VStack(spacing: 4) {
                Text("Game Code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(state.gameCode)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(4)
                ShareLink(item: shareURL, subject: Text("Join my Jeffopoly Deal game!")) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .font(.footnote)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Players (\(connectedCount)/5)")
                    .font(.headline)
                ForEach(state.players) { p in
                    HStack {
                        Text(p.name + (p.playerId == myPlayerId ? " (you)" : ""))
                        if !p.isConnected {
                            Text("(reconnecting…)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .opacity(p.isConnected ? 1 : 0.5)
                }
                if canStart && state.players.count < 5 {
                    Button("+ Add Bot Player") { Task { await onAddBot() } }
                        .font(.footnote)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if canStart {
                Button {
                    Task { await onStartGame(minPlayers) }
                } label: {
                    Text(connectedCount < minPlayers ? "Start Game (need \(minPlayers)+ players)" : "Start Game")
                }
                .buttonStyle(.borderedProminent)
                .disabled(connectedCount < minPlayers)
            } else {
                Text("Waiting for host to start…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Exit Game", role: .destructive, action: onLeave)
                .buttonStyle(.bordered)
        }
        .padding()
    }

    private var shareURL: URL {
        // Mirrors the web's `${origin}?join=${gameCode}` deep link.
        URL(string: "https://jeffopolydeal.azurewebsites.net?join=\(state.gameCode)")!
    }
}
