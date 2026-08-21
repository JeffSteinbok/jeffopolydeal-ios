import SwiftUI

/// Direct port of src/web/pages/gamePage/components/PlayCardModal.tsx —
/// the multi-step flow for playing property wildcards, rent (+ Double The
/// Rent chaining), and targeted action cards (Sly Deal, Force Deal, Deal
/// Breaker, House, Hotel). Money/Property cards play in a single step;
/// PassGo/It's My Birthday play immediately once the action is chosen.
private enum PlayCardStep {
    case choice
    case pickTarget
    case pickTargetProperty
    case pickMyProperty
    case pickMySet
    case pickTargetSet
    case pickRentColor
    case pickDoubleRent
}

struct PlayCardSheet: View {
    let card: GameCard
    let gameState: GameState
    let myState: PlayerState
    let canPlay: Bool
    let onPlay: (Int, PlayCardRequest) -> Void
    let onCancel: () -> Void

    @State private var step: PlayCardStep = .choice
    @State private var request = PlayCardRequest(playAsMoney: false)

    private var otherPlayers: [PlayerState] {
        gameState.players.filter { $0.connectionId != myState.connectionId }
    }
    private var canPlayAsMoney: Bool { card.moneyValue > 0 }
    private var actionPlayable: Bool { canUseAction() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CardComponentView(card: card)
                    body(for: effectiveStep)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Money/Property/read-only/wildcard aren't part of the `step` state
    /// machine (they're single-screen), so route those ahead of `step`.
    private enum EffectiveStep { case money, property, readOnly, wildcardColor, machine }
    private var effectiveStep: EffectiveStep {
        if card.cardType == .money { return .money }
        if card.cardType == .property { return .property }
        if !canPlay { return .readOnly }
        if card.cardType == .propertyWildcard { return .wildcardColor }
        return .machine
    }

    @ViewBuilder
    private func body(for effective: EffectiveStep) -> some View {
        switch effective {
        case .money:
            if canPlay {
                Button("◆ Bank") { onPlay(card.id, PlayCardRequest(playAsMoney: true)) }
                    .buttonStyle(.borderedProminent)
            }
        case .property:
            if canPlay {
                Button("🏘️ Place") { onPlay(card.id, PlayCardRequest(playAsMoney: false)) }
                    .buttonStyle(.borderedProminent)
            }
        case .readOnly:
            EmptyView()
        case .wildcardColor:
            wildcardColorView
        case .machine:
            machineView
        }
    }

    // MARK: - Property Wildcard: choose color

    private var wildcardColorView: some View {
        let colorOptions: [PropertyColor] = card.isMulticolorWild
            ? PropertyColorOrder.filter { color in myState.propertySets.contains { $0.color == color } }
            : [card.color, card.altColor].compactMap { $0 }

        return VStack(spacing: 12) {
            Text("Place as which color?").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                ForEach(colorOptions, id: \.self) { color in
                    Button {
                        onPlay(card.id, PlayCardRequest(playAsMoney: false, wildcardColor: color))
                    } label: {
                        Circle().fill(PropertyColorMap[color]!.hex).frame(width: 44, height: 44)
                    }
                }
                if card.isMulticolorWild {
                    Button("Unassigned") { onPlay(card.id, PlayCardRequest(playAsMoney: false)) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Action/Rent step machine

    @ViewBuilder
    private var machineView: some View {
        switch step {
        case .choice: choiceView
        case .pickRentColor: pickRentColorView
        case .pickDoubleRent: pickDoubleRentView
        case .pickTarget: pickTargetView
        case .pickTargetProperty: pickTargetPropertyView
        case .pickMyProperty: pickMyPropertyView
        case .pickTargetSet: pickTargetSetView
        case .pickMySet: pickMySetView
        }
    }

    private var choiceView: some View {
        VStack(spacing: 12) {
            Button(card.cardType == .rent ? "⚡ Charge Rent" : "⚡ Use Action") {
                handlePlayAsAction()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!actionPlayable)

            if canPlayAsMoney {
                Button("◆ Bank") { onPlay(card.id, PlayCardRequest(playAsMoney: true)) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var pickRentColorView: some View {
        let options = rentColorOptions
        return VStack(spacing: 12) {
            Text("Choose color to charge rent for").font(.headline)
            ForEach(options, id: \.color) { opt in
                Button("\(PropertyColorMap[opt.color]!.name) (◆\(opt.rent))") {
                    request.rentColor = opt.color
                    let doubleCards = (myState.hand ?? []).filter { $0.actionKind == .doubleTheRent && $0.id != card.id }
                    if !doubleCards.isEmpty, gameState.playsUsed + 1 < 3 {
                        step = .pickDoubleRent
                    } else if card.isWildRent {
                        step = .pickTarget
                    } else {
                        request.playAsMoney = false
                        onPlay(card.id, request)
                    }
                }
                .buttonStyle(.bordered)
            }
            if options.isEmpty {
                Text("You have no matching properties!").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var pickDoubleRentView: some View {
        let selectedDoubles = request.doubleRentCardIds ?? []
        let doubleCards = (myState.hand ?? []).filter {
            $0.actionKind == .doubleTheRent && $0.id != card.id && !selectedDoubles.contains($0.id)
        }
        let rentSet = myState.propertySets.first { $0.color == request.rentColor }
        let baseRent = rentSet?.rent ?? 0
        let multiplier = 1 << selectedDoubles.count
        let currentRent = baseRent * multiplier
        let doubledRent = currentRent * 2

        return VStack(spacing: 12) {
            Text(selectedDoubles.isEmpty ? "Double the Rent?" : "Double the Rent Again?").font(.headline)
            Text("Charge ◆\(doubledRent) instead of ◆\(currentRent)?\nUses an extra card play.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

            Button("⚡ Double It! (◆\(doubledRent))") {
                guard let first = doubleCards.first else { return }
                let newDoubles = selectedDoubles + [first.id]
                let playsAfter = gameState.playsUsed + 1 + newDoubles.count
                if doubleCards.count > 1, playsAfter < 3 {
                    request.doubleRentCardIds = newDoubles
                } else {
                    finishRent(newDoubles)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("No, Charge ◆\(currentRent)") { finishRent(selectedDoubles) }
                .buttonStyle(.bordered)
        }
    }

    private func finishRent(_ ids: [Int]) {
        request.doubleRentCardIds = ids.isEmpty ? nil : ids
        if card.isWildRent {
            step = .pickTarget
        } else {
            request.playAsMoney = false
            onPlay(card.id, request)
        }
    }

    private var pickTargetView: some View {
        VStack(spacing: 12) {
            Text("Choose target player").font(.headline)
            ForEach(otherPlayers) { p in
                Button {
                    request.targetPlayerId = p.connectionId
                    switch card.actionKind {
                    case .slyDeal, .forceDeal: step = .pickTargetProperty
                    case .dealBreaker: step = .pickTargetSet
                    default:
                        request.playAsMoney = false
                        onPlay(card.id, request)
                    }
                } label: {
                    HStack {
                        Text(p.name)
                        Spacer()
                        Text("◆\(p.bank.reduce(0) { $0 + $1.moneyValue })").foregroundStyle(.green)
                        Text("\(p.handCount) cards")
                        Text("\(p.completedSetCount)/3")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var pickTargetPropertyView: some View {
        let target = gameState.players.first { $0.connectionId == request.targetPlayerId }
        let stealable = (target?.propertySets.filter { !$0.isComplete }.flatMap(\.cards) ?? [])
            + (target?.unboundWilds ?? [])

        return VStack(spacing: 12) {
            Text("Pick a property to \(card.actionKind == .slyDeal ? "steal" : "swap for")").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                ForEach(stealable) { c in
                    ScaledCardView(card: c, scale: ScaledCardView.compactScale)
                        .onTapGesture {
                            request.targetCardId = c.id
                            if card.actionKind == .forceDeal {
                                step = .pickMyProperty
                            } else {
                                request.playAsMoney = false
                                onPlay(card.id, request)
                            }
                        }
                }
            }
            if stealable.isEmpty {
                Text("No stealable properties (complete sets are protected)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var pickMyPropertyView: some View {
        let myStealable = myState.propertySets.filter { !$0.isComplete }.flatMap(\.cards)
        return VStack(spacing: 12) {
            Text("Pick your property to offer in exchange").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                ForEach(myStealable) { c in
                    ScaledCardView(card: c, scale: ScaledCardView.compactScale)
                        .onTapGesture {
                            request.offeredCardId = c.id
                            request.playAsMoney = false
                            onPlay(card.id, request)
                        }
                }
            }
            if myStealable.isEmpty {
                Text("You have no properties to offer!").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var pickTargetSetView: some View {
        let target = gameState.players.first { $0.connectionId == request.targetPlayerId }
        let completeSets = target?.propertySets.filter(\.isComplete) ?? []
        return VStack(spacing: 12) {
            Text("Pick a complete set to steal").font(.headline)
            ForEach(completeSets) { s in
                Button("\(PropertyColorMap[s.color]!.name) (\(s.cards.count) cards)") {
                    request.targetSetColor = s.color
                    request.playAsMoney = false
                    onPlay(card.id, request)
                }
                .buttonStyle(.bordered)
            }
            if completeSets.isEmpty {
                Text("No complete sets to steal!").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var pickMySetView: some View {
        let eligible = myState.propertySets.filter { s in
            guard s.isComplete, s.color != .railroad, s.color != .utility else { return false }
            if card.actionKind == .house { return !s.hasHouse }
            if card.actionKind == .hotel { return s.hasHouse && !s.hasHotel }
            return false
        }
        let bonus = card.actionKind == .house ? 3 : 4

        return VStack(spacing: 12) {
            Text("Pick a Set").font(.headline)
            Text("New rent values shown below").font(.caption).foregroundStyle(.secondary)
            ForEach(eligible) { s in
                Button("\(PropertyColorMap[s.color]!.name) (◆\(s.rent + bonus))") {
                    request.targetSetColor = s.color
                    request.playAsMoney = false
                    onPlay(card.id, request)
                }
                .buttonStyle(.bordered)
            }
            if eligible.isEmpty {
                Text("No eligible sets!").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers (ported verbatim from PlayCardModal.tsx)

    private var rentColorOptions: [(color: PropertyColor, rent: Int)] {
        var best: [PropertyColor: PropertySetState] = [:]
        for set in myState.propertySets {
            if set.cards.isEmpty { continue }
            if !card.isWildRent, !(card.rentColors?.contains(set.color) ?? false) { continue }
            if let existing = best[set.color], existing.rent >= set.rent { continue }
            best[set.color] = set
        }
        return best.map { (color: $0.key, rent: $0.value.rent) }
            .sorted { $0.color.rawValue < $1.color.rawValue }
    }

    private func canUseAction() -> Bool {
        if let isPlayable = card.isPlayable { return isPlayable }

        if card.cardType == .rent {
            let myColors = myState.propertySets.filter { !$0.cards.isEmpty }.map(\.color)
            if card.isWildRent { return !myColors.isEmpty }
            return myColors.contains { card.rentColors?.contains($0) ?? false }
        }

        func hasStealable(_ p: PlayerState) -> Bool {
            p.propertySets.contains { !$0.isComplete && !$0.cards.isEmpty } || !p.unboundWilds.isEmpty
        }

        switch card.actionKind {
        case .passGo: return true
        case .itsMyBirthday, .debtCollector: return !otherPlayers.isEmpty
        case .slyDeal: return otherPlayers.contains { hasStealable($0) }
        case .forceDeal: return hasStealable(myState) && otherPlayers.contains { hasStealable($0) }
        case .dealBreaker: return otherPlayers.contains { p in p.propertySets.contains(where: \.isComplete) }
        case .house:
            return myState.propertySets.contains { $0.isComplete && !$0.hasHouse && $0.color != .railroad && $0.color != .utility }
        case .hotel:
            return myState.propertySets.contains { $0.isComplete && $0.hasHouse && !$0.hasHotel && $0.color != .railroad && $0.color != .utility }
        default: return false
        }
    }

    private func handlePlayAsAction() {
        guard actionPlayable else { return }

        if card.cardType == .rent {
            step = .pickRentColor
            return
        }

        switch card.actionKind {
        case .passGo, .itsMyBirthday:
            onPlay(card.id, PlayCardRequest(playAsMoney: false))
        case .debtCollector, .slyDeal, .forceDeal, .dealBreaker:
            step = .pickTarget
        case .house, .hotel:
            step = .pickMySet
        default:
            onPlay(card.id, PlayCardRequest(playAsMoney: true))
        }
    }
}
