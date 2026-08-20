import SwiftUI

// Gallery of sample cards exercising every layout branch in CardView.swift,
// for visual comparison against the web version's Card.tsx render.

private func propertyCard(_ color: PropertyColor, _ name: String) -> GameCard {
    GameCard(cardType: .property, moneyValue: GameConfig.setSize[color] ?? 0, name: name, color: color)
}

private func moneyCard(_ value: Int) -> GameCard {
    GameCard(cardType: .money, moneyValue: value, name: "\(value)M")
}

private func actionCard(_ kind: ActionKind, value: Int = 0) -> GameCard {
    GameCard(cardType: .action, moneyValue: value, name: kind.meta.title, actionKind: kind)
}

private let sampleCards: [GameCard] = [
    GameCard(cardType: .rent, name: "Wild Rent", isWildRent: true),
    GameCard(cardType: .rent, name: "Rent", rentColors: [.brown, .lightBlue]),
    actionCard(.passGo),
    actionCard(.house),
    actionCard(.hotel),
    actionCard(.itsMyBirthday, value: 2),
    actionCard(.debtCollector, value: 5),
    actionCard(.slyDeal),
    actionCard(.dealBreaker),
    actionCard(.justSayNo),
    moneyCard(1), moneyCard(5), moneyCard(10),
    propertyCard(.brown, "Baltic Avenue"),
    propertyCard(.railroad, "Reading Railroad"),
    propertyCard(.darkBlue, "Boardwalk"),
    GameCard(cardType: .propertyWildcard, name: "Wild", isMulticolorWild: true),
    GameCard(cardType: .propertyWildcard, name: "Wild", color: .green, altColor: .darkBlue, activeColor: .green),
]

struct ContentView: View {
    let columns = [GridItem(.adaptive(minimum: 160), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(Array(sampleCards.enumerated()), id: \.offset) { _, card in
                    CardComponentView(card: card)
                }
                CardComponentView(card: propertyCard(.yellow, "Marvin Gardens"), currentRent: 4)
                CardComponentView(card: propertyCard(.pink, "Selected"), selected: true)
            }
            .padding(24)
        }
        .background(Color(hex: "#0b5c2e"))
    }
}

#Preview {
    ContentView()
}
