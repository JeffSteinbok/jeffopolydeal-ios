import SwiftUI

/// Mirrors the two-stage toast pipeline split across GamePage.tsx:134-186
/// (filter own/targeted-at-me actions out, stagger new ones 1200ms apart) and
/// FyiToast.tsx (one-at-a-time display queue, 3s auto-dismiss, busy-state
/// reported with a 1500ms falling-edge debounce so it doesn't flash other
/// modals). Consumers gate Draw/Discard/ActionResponse visibility on `busy`.
@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var current: GameAction?
    @Published private(set) var busy: Bool = false

    private var queue: [GameAction] = []
    private var seenIds: Set<Int> = []
    private var firstLoad = true
    private var busyFalseWorkItem: DispatchWorkItem?
    private var dismissWorkItem: DispatchWorkItem?

    func ingest(recentActions: [GameAction], myName: String?) {
        defer { seenIds.formUnion(recentActions.map(\.id)) }

        if firstLoad {
            firstLoad = false
            return
        }
        guard !recentActions.isEmpty else { return }

        let newActions = recentActions.filter { a in
            !seenIds.contains(a.id)
                && a.playerName != myName
                && !(a.targetPlayerName == myName && !a.text.hasPrefix("Paid"))
        }
        guard !newActions.isEmpty else { return }

        for (idx, action) in newActions.enumerated() {
            let delay = Double(idx) * 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.enqueue(action)
            }
        }
    }

    func dismissCurrent() {
        dismissWorkItem?.cancel()
        current = nil
        updateBusy()
        showNextIfNeeded()
    }

    private func enqueue(_ action: GameAction) {
        queue.append(action)
        updateBusy()
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard current == nil, !queue.isEmpty else { return }
        current = queue.removeFirst()
        let work = DispatchWorkItem { [weak self] in self?.dismissCurrent() }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    private func updateBusy() {
        let isBusyNow = current != nil || !queue.isEmpty
        guard isBusyNow != busy else { return }
        busyFalseWorkItem?.cancel()
        if isBusyNow {
            busy = true
        } else {
            let work = DispatchWorkItem { [weak self] in self?.busy = false }
            busyFalseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
    }
}

/// Mirrors src/web/pages/gamePage/components/FyiToast.tsx's card content
/// (inline bold-run text styling is skipped as a cosmetic simplification —
/// the my-name→"you" substitution, staggering, and card visuals are kept).
struct FyiToastView: View {
    let action: GameAction
    let myName: String?
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let card = action.cardPlayed {
                ScaledCardView(card: card, scale: ScaledCardView.compactScale)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(action.playerName).font(.caption.bold())
                Text(displayText).font(.caption)
                if hasCardRows {
                    HStack(spacing: 6) {
                        if let sourceCards = action.sourceCards, !sourceCards.isEmpty {
                            cardRow(label: hasBothRows ? "Gave" : nil, cards: sourceCards)
                        }
                        if hasBothRows { Text("⇄").font(.caption) }
                        if let targetCards = action.targetCards, !targetCards.isEmpty {
                            cardRow(label: hasBothRows ? "Got" : nil, cards: targetCards)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6)
        .padding(.horizontal)
    }

    private var displayText: String {
        guard let myName, action.text.contains(myName) else { return action.text }
        return action.text.replacingOccurrences(of: myName, with: "you")
    }

    private var hasCardRows: Bool {
        !(action.sourceCards ?? []).isEmpty || !(action.targetCards ?? []).isEmpty
    }
    private var hasBothRows: Bool {
        !(action.sourceCards ?? []).isEmpty && !(action.targetCards ?? []).isEmpty
    }

    private func cardRow(label: String?, cards: [GameCard]) -> some View {
        VStack(spacing: 2) {
            if let label { Text(label).font(.caption2).foregroundStyle(.secondary) }
            HStack(spacing: 2) {
                ForEach(cards) { c in ScaledCardView(card: c, scale: ScaledCardView.compactScale * 0.6) }
            }
        }
    }
}
