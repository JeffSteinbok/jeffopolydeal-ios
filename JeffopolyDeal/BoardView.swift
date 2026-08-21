import SwiftUI

/// Mirrors the active-game (Draw/Play/Discard/AwaitingResponse) layout in
/// GamePage.tsx:400-644 — opponent boards, my board, my hand, plus the
/// ActionResponseSheet/DiscardSheet modals driven by server phase/pendingAction.
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

    @StateObject private var toastCenter = ToastCenter()
    @State private var inspectedPlayer: PlayerState?

    private var showDiscard: Bool { state.phase == .discard && isMyTurn && !toastCenter.busy }
    private var showActionResponse: Bool {
        guard state.phase == .awaitingResponse, let pending = state.pendingAction, let myConnectionId = me?.connectionId, !toastCenter.busy else { return false }
        return pending.targetPlayerIds.contains(myConnectionId)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(opponents) { p in
                        PlayerBoardView(player: p, isMe: false, isCurrentTurn: currentPlayer?.playerId == p.playerId, compact: true)
                            .onTapGesture { inspectedPlayer = p }
                    }
                    if let me {
                        PlayerBoardView(
                            player: me,
                            isMe: true,
                            isCurrentTurn: isMyTurn,
                            compact: false,
                            onFlipCard: { cardId in Task { try? await hub.flipWildcard(cardId: cardId) } },
                            onMoveProperty: { cardId, targetSetId, targetColor in
                                Task { try? await hub.moveProperty(cardId: cardId, targetSetId: targetSetId, targetColor: targetColor) }
                            }
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
                    gameState: state,
                    myState: me,
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
            if isMyTurn && state.phase == .draw && !toastCenter.busy {
                DrawPopup { Task { try? await hub.drawCards() } }
            }
        }
        .safeAreaInset(edge: .top) {
            if let toast = toastCenter.current {
                FyiToastView(action: toast, myName: me?.name, onDismiss: { toastCenter.dismissCurrent() })
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toastCenter.current)
        .onChange(of: state.recentActions) { _, newActions in
            toastCenter.ingest(recentActions: newActions, myName: me?.name)
        }
        .sheet(item: $inspectedPlayer) { p in PlayerInspectSheet(player: p) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Leave", role: .destructive, action: onLeave)
            }
        }
        .sheet(isPresented: .constant(showDiscard)) {
            DiscardSheet(
                hand: me?.hand ?? [],
                maxHandSize: 7,
                onDiscard: { ids in
                    Task { for id in ids { try? await hub.discardCard(cardId: id) } }
                },
                onCancel: state.playsUsed < 3 ? { Task { try? await hub.cancelDiscard() } } : nil
            )
        }
        .sheet(isPresented: .constant(showActionResponse)) {
            if let pending = state.pendingAction, let me {
                ActionResponseSheet(
                    pendingAction: pending,
                    myState: me,
                    otherPlayers: opponents,
                    paymentError: state.paymentError,
                    onRespond: { response in Task { try? await hub.respondToAction(response) } }
                )
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
