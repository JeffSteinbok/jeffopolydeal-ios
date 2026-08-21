import SwiftUI

/// Mirrors src/web/pages/gamePage/components/DiscardModal.tsx — end-of-turn
/// forced discard when the hand exceeds maxHandSize.
struct DiscardSheet: View {
    let hand: [GameCard]
    let maxHandSize: Int
    let onDiscard: ([Int]) -> Void
    let onCancel: (() -> Void)?

    @State private var selectedCardIds: Set<Int> = []

    private var excess: Int { hand.count - maxHandSize }
    private var remaining: Int { excess - selectedCardIds.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You have \(hand.count) cards — max is \(maxHandSize). Select \(excess) to discard.")
                        .font(.subheadline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(hand) { card in
                            let isSelected = selectedCardIds.contains(card.id)
                            let isDimmed = remaining <= 0 && !isSelected
                            ScaledCardView(card: card, scale: ScaledCardView.compactScale, selected: isSelected, dimmed: isDimmed)
                                .onTapGesture { toggleCard(card.id) }
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    if let onCancel {
                        Button("Go Back & Play", action: onCancel)
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    Button("Discard \(excess) card\(excess != 1 ? "s" : "")") {
                        if remaining <= 0 { onDiscard(Array(selectedCardIds)) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(remaining > 0)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Discard Cards")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private func toggleCard(_ id: Int) {
        if selectedCardIds.contains(id) {
            selectedCardIds.remove(id)
        } else if selectedCardIds.count < excess {
            selectedCardIds.insert(id)
        }
    }
}
