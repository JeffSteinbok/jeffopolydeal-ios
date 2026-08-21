import SwiftUI

/// Direct port of src/web/pages/gamePage/components/ActionModal.tsx — shown
/// to the player(s) targeted by a pending action: payment (rent/debt
/// collector/birthday), accept/decline a steal/swap, or a Just-Say-No chain.
struct ActionResponseSheet: View {
    let pendingAction: PendingAction
    let myState: PlayerState
    let otherPlayers: [PlayerState]
    let paymentError: String?
    let onRespond: (ActionResponse) -> Void

    @State private var selectedCardIds: Set<Int> = []
    @State private var inspectedPlayer: PlayerState?
    @State private var showHand = false

    private let gridColumns = [GridItem(.adaptive(minimum: 70))]

    private var hasJustSayNo: Bool { (myState.hand ?? []).contains { $0.actionKind == .justSayNo } }
    private var isPayment: Bool {
        [.payRent, .payDebtCollector, .payBirthday].contains(pendingAction.type)
    }
    private var isStealResponse: Bool {
        [.respondToSlyDeal, .respondToForceDeal, .respondToDealBreaker].contains(pendingAction.type)
    }
    private var who: String { pendingAction.sourcePlayerName.isEmpty ? "Someone" : pendingAction.sourcePlayerName }

    private var bankCards: [GameCard] { myState.bank.sorted { $0.moneyValue < $1.moneyValue } }
    private var propertySetsWithCards: [PropertySetState] {
        myState.propertySets
            .filter { !$0.cards.isEmpty }
            .map { set -> PropertySetState in
                var s = set
                s.cards = set.cards.sorted { $0.moneyValue < $1.moneyValue }
                return s
            }
            .sorted { (PropertyColorOrder.firstIndex(of: $0.color) ?? 0) < (PropertyColorOrder.firstIndex(of: $1.color) ?? 0) }
    }
    private var allPropertyCards: [GameCard] { propertySetsWithCards.flatMap(\.cards) }
    private var selectablePropertyCards: [GameCard] { allPropertyCards.filter { !$0.isMulticolorWild } }
    private var payableCards: [GameCard] { bankCards + selectablePropertyCards }

    private var selectedTotal: Int {
        selectedCardIds.reduce(0) { sum, id in sum + (payableCards.first { $0.id == id }?.moneyValue ?? 0) }
    }
    private var totalAssets: Int { payableCards.reduce(0) { $0 + $1.moneyValue } }
    private var canAfford: Bool { totalAssets >= pendingAction.amount }
    private var needsMore: Bool { isPayment && canAfford && !payableCards.isEmpty && selectedTotal < pendingAction.amount }
    private var amountMet: Bool { canAfford && selectedTotal >= pendingAction.amount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title).font(.title3.bold())
                    if isPayment {
                        paymentContent
                    } else {
                        responseContent
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) { actionBar }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .sheet(item: $inspectedPlayer) { p in PlayerInspectSheet(player: p) }
        .sheet(isPresented: $showHand) { handSheet }
        .onChange(of: payableCards.map(\.id)) { _, ids in
            selectedCardIds = selectedCardIds.filter { ids.contains($0) }
        }
    }

    // MARK: - Content

    private var title: String {
        switch pendingAction.type {
        case .payRent: return "\(who) charges you rent of ◆\(pendingAction.amount)!"
        case .payDebtCollector: return "\(who) plays Debt Collector!"
        case .payBirthday: return "It's \(who)'s Birthday!"
        case .respondToSlyDeal: return "\(who) plays Sly Deal!"
        case .respondToForceDeal: return "\(who) plays Forced Deal!"
        case .respondToDealBreaker: return "\(who) plays Deal Breaker!"
        case .justSayNoChain: return hasJustSayNo ? "\(who) played Just Say No! Counter it?" : "\(who) played Just Say No!"
        }
    }

    private var description: String? {
        switch pendingAction.type {
        case .payRent: return "Pay ◆\(pendingAction.amount) in rent."
        case .payDebtCollector: return "Pay ◆\(pendingAction.amount) to \(who)."
        case .payBirthday: return "Pay ◆\(pendingAction.amount) as a birthday gift."
        case .respondToSlyDeal: return "\(who) stole \(pendingAction.targetCardName ?? "a property")."
        case .respondToForceDeal: return "\(who) swapped your \(pendingAction.targetCardName ?? "property") for their \(pendingAction.offeredCardName ?? "property")."
        case .respondToDealBreaker: return "\(who) took your complete \(pendingAction.targetSetColor?.rawValue ?? "") property set!"
        default: return nil
        }
    }

    private var targetCard: GameCard? {
        guard let id = pendingAction.targetCardId else { return nil }
        for set in myState.propertySets {
            if let c = set.cards.first(where: { $0.id == id }) { return c }
        }
        return myState.unboundWilds.first { $0.id == id }
    }

    private var offeredCard: GameCard? {
        guard let id = pendingAction.offeredCardId else { return nil }
        if let source = otherPlayers.first(where: { $0.name == pendingAction.sourcePlayerName }) {
            for set in source.propertySets {
                if let c = set.cards.first(where: { $0.id == id }) { return c }
            }
            if let wild = source.unboundWilds.first(where: { $0.id == id }) { return wild }
        }
        if let name = pendingAction.offeredCardName {
            return GameCard(id: id, cardType: .property, name: name)
        }
        return nil
    }

    @ViewBuilder
    private var paymentContent: some View {
        if canAfford {
            Text("\(description ?? "") Select cards (◆\(selectedTotal) / ◆\(pendingAction.amount)):")
                .font(.subheadline)
        } else {
            Text("You can't afford ◆\(pendingAction.amount).").foregroundStyle(.red)
        }
        if let paymentError {
            Text(paymentError).font(.caption).foregroundStyle(.red)
        }

        if !bankCards.isEmpty {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(bankCards) { paymentCard($0) }
            }
        }
        ForEach(propertySetsWithCards) { set in
            VStack(alignment: .leading, spacing: 4) {
                setHeader(set)
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(set.cards) { card in
                        paymentCard(card, disabledSelect: card.isMulticolorWild)
                    }
                }
            }
        }
        if bankCards.isEmpty && allPropertyCards.isEmpty {
            Text("You have nothing to pay with!").foregroundStyle(.secondary)
        }
    }

    private func setHeader(_ set: PropertySetState) -> some View {
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
        .background(PropertyColorMap[set.color]!.hex)
        .foregroundStyle(PropertyColorMap[set.color]!.textColor)
        .clipShape(Capsule())
    }

    private func paymentCard(_ card: GameCard, disabledSelect: Bool = false) -> some View {
        let isSelected = disabledSelect ? true : (canAfford ? selectedCardIds.contains(card.id) : true)
        let isDimmed = disabledSelect || (amountMet && !selectedCardIds.contains(card.id))
        return ScaledCardView(card: card, scale: ScaledCardView.compactScale, selected: isSelected, dimmed: isDimmed)
            .onTapGesture { if !disabledSelect { toggleCard(card.id) } }
    }

    @ViewBuilder
    private var responseContent: some View {
        if let description {
            Text(description)
        }
        if pendingAction.type == .respondToForceDeal, let targetCard, let offeredCard {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Yours").font(.caption).foregroundStyle(.secondary)
                    ScaledCardView(card: targetCard, scale: ScaledCardView.compactScale)
                }
                Text("⇄").font(.title2)
                VStack(spacing: 4) {
                    Text("Theirs").font(.caption).foregroundStyle(.secondary)
                    ScaledCardView(card: offeredCard, scale: ScaledCardView.compactScale)
                }
            }
        }
        if pendingAction.type == .respondToSlyDeal, let targetCard {
            ScaledCardView(card: targetCard, scale: ScaledCardView.compactScale)
        }
    }

    // MARK: - Action bar

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            switch pendingAction.type {
            case .payRent, .payDebtCollector, .payBirthday:
                HStack {
                    Button(payButtonLabel, action: handlePay)
                        .buttonStyle(.borderedProminent)
                        .disabled(needsMore)
                    if hasJustSayNo {
                        Button("Just Say No!", action: handleJustSayNo)
                            .buttonStyle(.bordered)
                    }
                }
            case .respondToSlyDeal, .respondToForceDeal, .respondToDealBreaker:
                HStack {
                    if hasJustSayNo {
                        Button("Accept", action: handleAccept).buttonStyle(.bordered)
                        Button("Just Say No!", action: handleJustSayNo).buttonStyle(.borderedProminent)
                    } else {
                        Button("Ok", action: handleAccept).buttonStyle(.borderedProminent)
                    }
                }
            case .justSayNoChain:
                HStack {
                    if hasJustSayNo {
                        Button("Let it go", action: handleAccept).buttonStyle(.bordered)
                        Button("Counter with Just Say No!", action: handleJustSayNo).buttonStyle(.borderedProminent)
                    } else {
                        Button("Ok", action: handleAccept).buttonStyle(.borderedProminent)
                    }
                }
            }

            if hasJustSayNo, !otherPlayers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(otherPlayers) { p in
                            Button("🔍 \(p.name)") { inspectedPlayer = p }
                                .font(.caption)
                        }
                        Button {
                            showHand = true
                        } label: {
                            Label("Your hand", systemImage: "rectangle.stack")
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private var payButtonLabel: String {
        if payableCards.isEmpty { return "I have nothing" }
        if canAfford { return "Pay ◆\(selectedTotal)" }
        return "Give Everything (◆\(totalAssets))"
    }

    private var handSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(myState.hand ?? []) { c in ScaledCardView(card: c, scale: ScaledCardView.compactScale) }
                }
                .padding()
            }
            .navigationTitle("Your Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showHand = false } }
            }
        }
    }

    // MARK: - Actions

    private func toggleCard(_ id: Int) {
        guard canAfford else { return }
        if !selectedCardIds.contains(id), selectedTotal >= pendingAction.amount { return }
        if selectedCardIds.contains(id) { selectedCardIds.remove(id) } else { selectedCardIds.insert(id) }
    }

    private func handlePay() {
        let validIds = selectedCardIds.filter { id in payableCards.contains { $0.id == id } }
        onRespond(ActionResponse(playJustSayNo: false, paymentCardIds: canAfford ? Array(validIds) : []))
    }

    private func handleJustSayNo() {
        onRespond(ActionResponse(playJustSayNo: true))
    }

    private func handleAccept() {
        onRespond(ActionResponse(playJustSayNo: false, paymentCardIds: []))
    }
}

/// Mirrors src/web/pages/gamePage/components/PlayerInspectModal.tsx — a
/// read-only compact PlayerBoardView in a sheet.
struct PlayerInspectSheet: View {
    let player: PlayerState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PlayerBoardView(player: player, isMe: false, isCurrentTurn: false, compact: true, inspectMode: true)
                    .padding()
            }
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
