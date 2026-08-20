import SwiftUI

// Mirrors src/web/pages/gamePage/components/Hand.tsx.
struct HandView: View {
    let cards: [GameCard]
    let canPlay: Bool
    let phase: GamePhase
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
            PlayCardSheet(card: card, canPlay: canPlay, phase: phase) { cardId, request in
                onPlayCard(cardId, request)
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

/// Mirrors src/web/pages/gamePage/components/PlayCardModal.tsx.
/// Phase 2 scope: Money ("Bank") and Property ("Place") only — the full
/// 9-step action/wildcard/rent state machine is Phase 3.
struct PlayCardSheet: View {
    let card: GameCard
    let canPlay: Bool
    let phase: GamePhase
    let onPlay: (Int, PlayCardRequest) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                CardComponentView(card: card)
                if canPlay, phase == .play {
                    actions
                } else {
                    Text("Not playable right now").foregroundStyle(.secondary)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var actions: some View {
        switch card.cardType {
        case .money:
            Button("◆ Bank") { onPlay(card.id, PlayCardRequest(playAsMoney: true)) }
                .buttonStyle(.borderedProminent)
        case .property:
            Button("🏘️ Place") { onPlay(card.id, PlayCardRequest(playAsMoney: false)) }
                .buttonStyle(.borderedProminent)
        default:
            VStack(spacing: 8) {
                Text("This card type isn't playable yet.").foregroundStyle(.secondary)
                if card.moneyValue > 0 {
                    Button("◆ Bank") { onPlay(card.id, PlayCardRequest(playAsMoney: true)) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
