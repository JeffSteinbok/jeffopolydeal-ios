import SwiftUI

/// Mirrors the active-game (Draw/Play/Discard/AwaitingResponse) layout in
/// GamePage.tsx:400-644 — opponent boards, my board, my hand. AwaitingResponse
/// (ActionModal) and Discard (DiscardModal) sheets land in Phase 4; for now
/// their state is visible on the board but there's no dedicated sheet yet.
struct BoardView: View {
    let state: GameState
    let myPlayerId: String
    let hub: GameHubClient
    let onLeave: () -> Void

    private var me: PlayerState? { state.players.first { $0.playerId == myPlayerId } }
    private var currentPlayer: PlayerState? {
        state.players.indices.contains(state.currentPlayerIndex) ? state.players[state.currentPlayerIndex] : nil
    }
    private var isMyTurn: Bool { currentPlayer?.playerId == myPlayerId }
    private var opponents: [PlayerState] { state.players.filter { $0.playerId != myPlayerId } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(opponents) { p in
                        PlayerBoardView(player: p, isMe: false, isCurrentTurn: currentPlayer?.playerId == p.playerId, compact: true)
                    }
                    if let me {
                        PlayerBoardView(
                            player: me,
                            isMe: true,
                            isCurrentTurn: isMyTurn,
                            compact: false,
                            onFlipCard: { cardId in Task { try? await hub.flipWildcard(cardId: cardId) } }
                        )
                    }
                }
                .padding()
            }

            if let me {
                Divider()
                HandView(
                    cards: me.hand ?? [],
                    canPlay: isMyTurn && (state.phase == .play || state.phase == .discard),
                    phase: state.phase,
                    playsRemaining: max(0, 3 - state.playsUsed),
                    isMyTurn: isMyTurn,
                    onEndTurn: { Task { try? await hub.endTurn() } },
                    onPlayCard: { cardId, request in Task { try? await hub.playCard(cardId: cardId, request: request) } },
                    onDiscardCard: { cardId in Task { try? await hub.discardCard(cardId: cardId) } }
                )
                .padding()
                .background(.bar)
            }
        }
        .overlay {
            if isMyTurn && state.phase == .draw {
                DrawPopup { Task { try? await hub.drawCards() } }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Leave", role: .destructive, action: onLeave)
            }
        }
    }
}

private struct DrawPopup: View {
    let onDraw: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("It's Your Turn!").font(.title3.bold())
            Button("Draw Cards", action: onDraw)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 12)
    }
}
