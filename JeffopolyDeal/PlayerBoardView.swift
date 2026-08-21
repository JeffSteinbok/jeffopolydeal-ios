import SwiftUI

// Mirrors src/web/pages/gamePage/components/PlayerBoard.tsx: bank, property
// sets, house/hotel indicators, tap-to-expand set + flip, and drag-and-drop
// to move properties between sets (native SwiftUI .draggable/.dropDestination
// in place of the web's HTML5-DnD/pointer-tracking dual implementation).
// setId sentinels match the server contract: 0 = new set, -1 = unbind wildcard.

private extension View {
    @ViewBuilder
    func draggableIf(_ condition: Bool, _ payload: String) -> some View {
        if condition {
            self.draggable(payload)
        } else {
            self
        }
    }
}

private let moneyColors: [Int: Color] = [
    1: Color(hex: "#f0ecc8"), 2: Color(hex: "#e8c8b0"), 3: Color(hex: "#d4e4bc"),
    4: Color(hex: "#b8d4e8"), 5: Color(hex: "#8b7bb5"), 10: Color(hex: "#e8c870"),
]

struct PlayerBoardView: View {
    let player: PlayerState
    var isMe: Bool = false
    var isCurrentTurn: Bool = false
    var compact: Bool = false
    var inspectMode: Bool = false
    var onFlipCard: ((Int) -> Void)? = nil
    var onMoveProperty: ((_ cardId: Int, _ targetSetId: Int, _ targetColor: PropertyColor?) -> Void)? = nil

    @State private var expandedSet: PropertySetState?

    private var canDrag: Bool { isMe && isCurrentTurn && onMoveProperty != nil }

    private func findCard(_ id: Int) -> GameCard? {
        for set in player.propertySets {
            if let c = set.cards.first(where: { $0.id == id }) { return c }
        }
        return player.unboundWilds.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            header
            bankDisplay
            properties
        }
        .padding(compact ? 8 : 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentTurn ? Color.accentColor : .clear, lineWidth: 2)
        )
        .sheet(item: $expandedSet) { set in
            SetDetailSheet(set: set, isMe: isMe, onFlipCard: onFlipCard)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 4) {
                if isCurrentTurn {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
                Text(player.name).font(compact ? .subheadline.bold() : .headline)
            }
            Spacer()
            Label("\(player.bank.reduce(0) { $0 + $1.moneyValue })", systemImage: "diamond.fill")
                .font(.caption.bold())
            Label("\(isMe ? (player.hand?.count ?? 0) : player.handCount)", systemImage: "rectangle.stack.fill")
                .font(.caption)
        }
    }

    private var bankDisplay: some View {
        let denoms = Dictionary(grouping: player.bank, by: \.moneyValue)
            .map { (value: $0.key, count: $0.value.count) }
            .sorted { $0.value < $1.value }

        return HStack(spacing: 4) {
            if denoms.isEmpty {
                Text("Bank Empty").font(.caption2).foregroundStyle(.secondary)
            } else {
                ForEach(denoms, id: \.value) { d in
                    Text("◆\(d.value) ×\(d.count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(moneyColors[d.value] ?? Color(hex: "#4caf50"))
                        .foregroundStyle(d.value == 5 ? .white : .black)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var properties: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Properties").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(player.completedSetCount)/3 sets").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(player.propertySets) { set in
                        PropertySetColumn(set: set, compact: compact, canDrag: canDrag, onTap: { expandedSet = set }) { cardId in
                            onMoveProperty?(cardId, set.setId, set.color)
                        }
                    }
                    if isMe || inspectMode, !player.unboundWilds.isEmpty {
                        UnboundColumn(cards: player.unboundWilds, compact: compact, canDrag: canDrag) { cardId in
                            onMoveProperty?(cardId, -1, nil)
                        }
                    }
                    if canDrag {
                        NewSetColumn { cardId in
                            let color = findCard(cardId).flatMap { $0.activeColor ?? $0.color }
                            onMoveProperty?(cardId, 0, color)
                        }
                    }
                    if player.propertySets.isEmpty && (player.unboundWilds.isEmpty || !(isMe || inspectMode)) && !canDrag {
                        Text("No properties").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct PropertySetColumn: View {
    let set: PropertySetState
    let compact: Bool
    let canDrag: Bool
    let onTap: () -> Void
    let onDrop: (Int) -> Void

    @State private var isDropTarget = false
    private var info: PropertyColorInfo { PropertyColorMap[set.color]! }
    private var cardSize: CGSize { compact ? CGSize(width: 88, height: 123) : CGSize(width: 150, height: 210) }
    private var reveal: CGFloat { compact ? 58 : 110 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text("\(set.cards.count)/\(set.requiredSize)\(set.isComplete ? "✓" : "")")
                if set.hasHotel {
                    Image("HotelSmall").resizable().scaledToFit().frame(width: 14)
                } else if set.hasHouse {
                    Image("HouseSmall").resizable().scaledToFit().frame(width: 14)
                }
            }
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(info.hex)
            .foregroundStyle(info.textColor)
            .clipShape(Capsule())

            ZStack(alignment: .top) {
                ForEach(Array(set.cards.enumerated()), id: \.element.id) { idx, card in
                    ScaledCardView(card: card, scale: compact ? ScaledCardView.compactScale : 1.0, currentRent: set.rent)
                        .offset(y: CGFloat(idx) * reveal)
                        .draggableIf(canDrag, String(card.id))
                }
            }
            .frame(width: cardSize.width, height: reveal * CGFloat(max(set.cards.count - 1, 0)) + cardSize.height, alignment: .top)
            .onTapGesture(perform: onTap)
            .padding(4)
            .background(isDropTarget ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .dropDestination(for: String.self, action: { items, _ in
                guard canDrag, let idStr = items.first, let id = Int(idStr) else { return false }
                onDrop(id)
                return true
            }, isTargeted: { isDropTarget = $0 })
        }
    }
}

private struct UnboundColumn: View {
    let cards: [GameCard]
    let compact: Bool
    let canDrag: Bool
    let onDrop: (Int) -> Void

    @State private var isDropTarget = false
    private var cardSize: CGSize { compact ? CGSize(width: 88, height: 123) : CGSize(width: 150, height: 210) }
    private var reveal: CGFloat { compact ? 58 : 110 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unassigned")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color(.systemGray4))
                .clipShape(Capsule())

            ZStack(alignment: .top) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    ScaledCardView(card: card, scale: compact ? ScaledCardView.compactScale : 1.0)
                        .offset(y: CGFloat(idx) * reveal)
                        .draggableIf(canDrag, String(card.id))
                }
            }
            .frame(width: cardSize.width, height: reveal * CGFloat(max(cards.count - 1, 0)) + cardSize.height, alignment: .top)
            .padding(4)
            .background(isDropTarget ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .dropDestination(for: String.self, action: { items, _ in
                guard canDrag, let idStr = items.first, let id = Int(idStr) else { return false }
                onDrop(id)
                return true
            }, isTargeted: { isDropTarget = $0 })
        }
    }
}

private struct NewSetColumn: View {
    let onDrop: (Int) -> Void
    @State private var isDropTarget = false

    var body: some View {
        VStack {
            Text("New Set")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 90, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(isDropTarget ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .background(isDropTarget ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .dropDestination(for: String.self, action: { items, _ in
            guard let idStr = items.first, let id = Int(idStr) else { return false }
            onDrop(id)
            return true
        }, isTargeted: { isDropTarget = $0 })
    }
}

private struct SetDetailSheet: View {
    let set: PropertySetState
    let isMe: Bool
    let onFlipCard: ((Int) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(set.cards) { card in
                        VStack(spacing: 6) {
                            ScaledCardView(card: card, scale: ScaledCardView.compactScale)
                            if isMe, card.cardType == .propertyWildcard, !card.isMulticolorWild, let onFlipCard {
                                Button("Flip") { onFlipCard(card.id); dismiss() }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("\(set.color.rawValue) — \(set.cards.count)/\(set.requiredSize)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
