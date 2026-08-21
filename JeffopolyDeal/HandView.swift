import SwiftUI

// Mirrors src/web/pages/gamePage/components/Hand.tsx.
struct HandView: View {
    let cards: [GameCard]
    let canPlay: Bool
    let phase: GamePhase
    let gameState: GameState
    let myState: PlayerState
    let playsRemaining: Int
    let isMyTurn: Bool
    let onEndTurn: () -> Void
    let onPlayCard: (Int, PlayCardRequest) -> Void
    let onDiscardCard: (Int) -> Void

    @State private var selectedCard: GameCard?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your Hand (\(cards.count))").font(.subheadline.bold())
                Spacer()
                if isMyTurn && phase == .play {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i < (3 - playsRemaining) ? Color.accentColor : Color(.systemGray4))
                                .frame(width: 6, height: 6)
                        }
                        Button("End Turn", action: onEndTurn)
                            .font(.caption.bold())
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -40) {
                    ForEach(cards) { card in
                        CardComponentView(card: card, dimmed: !canPlay)
                            .onTapGesture { handleTap(card) }
                            .zIndex(selectedCard?.id == card.id ? 1 : 0)
                    }
                    if cards.isEmpty {
                        Text("No cards in hand").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 12)
            }
        }
        .sheet(item: $selectedCard) { card in
            PlayCardSheet(card: card, gameState: gameState, myState: myState, canPlay: canPlay) { cardId, request in
                onPlayCard(cardId, request)
                selectedCard = nil
            } onCancel: {
                selectedCard = nil
            }
        }
    }

    private func handleTap(_ card: GameCard) {
        if canPlay, phase == .discard {
            onDiscardCard(card.id)
            return
        }
        selectedCard = card
    }
}
