import SwiftUI

// Direct port of src/web/pages/gamePage/components/Card.tsx + Card.css (full size only —
// the "sm"/"xs" CSS breakpoints are handled here with a single continuous .scaleEffect
// instead of three hand-tuned CSS blocks, which is simpler to maintain).

private let valueColors: [Int: Color] = [
    0: Color(hex: "#c8c8c8"),
    1: Color(hex: "#f0ecc8"),
    2: Color(hex: "#e8c8b0"),
    3: Color(hex: "#d4e4bc"),
    4: Color(hex: "#b8d4e8"),
    5: Color(hex: "#8b7bb5"),
    10: Color(hex: "#e8c870"),
]

private func cardBackground(_ card: GameCard) -> Color {
    switch card.cardType {
    case .money:
        return valueColors[card.moneyValue] ?? Color(hex: "#a0c8a0")
    case .property:
        let color = card.activeColor ?? card.color
        return color.flatMap { PropertyColorMap[$0]?.hex } ?? Color(hex: "#bbb")
    case .propertyWildcard:
        return .white
    default:
        return valueColors[card.moneyValue] ?? Color(hex: "#c8c8c8")
    }
}

private func borderColor(_ card: GameCard) -> Color {
    if card.cardType == .property || card.cardType == .propertyWildcard {
        let color = card.activeColor ?? card.color
        return color.flatMap { PropertyColorMap[$0]?.hex } ?? Color(hex: "#888")
    }
    return Color(hex: "#888")
}

private func textShadowColor(_ textColor: Color) -> Color {
    textColor == .black ? Color.white.opacity(0.5) : Color.black.opacity(0.3)
}

struct CardComponentView: View {
    let card: GameCard
    var selected: Bool = false
    var dimmed: Bool = false
    var currentRent: Int? = nil

    static let width: CGFloat = 150
    static let height: CGFloat = 210

    var body: some View {
        let bg = cardBackground(card)
        let bc = borderColor(card)
        let isRegularProp = card.cardType == .property
        let isPropWild = card.cardType == .propertyWildcard
        let isProp = isRegularProp || isPropWild
        let outerBg: Color = isRegularProp ? .white : bg
        let innerBg: Color? = isRegularProp ? bg : nil
        let badgeBg: Color = isProp ? .white : bg
        let badgeBorder: Color = isRegularProp ? bc : Color.black.opacity(0.2)
        let showRentOverlay = currentRent != nil && (card.cardType == .property || card.cardType == .propertyWildcard)

        ZStack {
            innerBody(card)
                .frame(width: Self.width - 12, height: Self.height - 12)
                .background(innerBg ?? Color.black.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isProp ? Color.clear : Color.black.opacity(0.15), lineWidth: 2)
                )
        }
        .frame(width: Self.width, height: Self.height)
        .background(outerBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .bottomTrailing) {
            if showRentOverlay, let rent = currentRent {
                Text("◆\(rent)")
                    .font(.interBlack(14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(3)
                    .padding(4)
            }
        }
        .overlay(alignment: .topLeading) {
            if card.moneyValue > 0 {
                BadgeView(value: card.moneyValue, bg: badgeBg, borderColor: badgeBorder)
                    .padding(4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#2e7d32"), lineWidth: selected ? 5 : 0)
        )
        .shadow(color: .black.opacity(selected ? 0.8 : 0.3), radius: selected ? 16 : 5, x: 0, y: 2)
        .opacity(dimmed ? 0.35 : 1.0)
    }

    @ViewBuilder
    private func innerBody(_ card: GameCard) -> some View {
        switch card.cardType {
        case .money: MoneyLayoutView(card: card)
        case .property: PropertyLayoutView(card: card)
        case .propertyWildcard: WildcardLayoutView(card: card)
        case .rent: RentLayoutView(card: card)
        case .action: ActionLayoutView(card: card)
        }
    }
}

// MARK: - Badge

struct BadgeView: View {
    let value: Int
    let bg: Color
    let borderColor: Color

    var body: some View {
        ZStack {
            Circle().fill(bg)
            Circle().stroke(borderColor, lineWidth: 2)
            Text("\(value)")
                .font(.interBlack(14))
                .foregroundColor(.black)
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Money

struct MoneyLayoutView: View {
    let card: GameCard
    var body: some View {
        ZStack {
            Image("CurrencyBackground")
                .resizable()
                .scaledToFit()
                .opacity(0.12)
                .frame(width: 120, height: 120)
            Text("◆\(card.moneyValue)")
                .font(.interBlack(54))
                .foregroundColor(.black)
                .kerning(-2)
        }
    }
}

// MARK: - Property

struct PropertyLayoutView: View {
    let card: GameCard
    var body: some View {
        guard let color = card.color, let info = PropertyColorMap[color] else {
            return AnyView(Text(card.name).font(.interBold(12)))
        }
        let rents = GameConfig.rentTable[color] ?? []
        let setSize = GameConfig.setSize[color] ?? rents.count

        return AnyView(
            VStack(spacing: 0) {
                Text(card.name.uppercased())
                    .font(.interBold(12))
                    .foregroundColor(info.textColor)
                    .shadow(color: textShadowColor(info.textColor), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .frame(height: 34)
                RentTableView(rents: rents, setSize: setSize, color: info.hex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.init(top: 2, leading: 15, bottom: 4, trailing: 20))
                    .background(Color.white)
            }
        )
    }
}

// MARK: - Property Wildcard

private let rainbowColors: [Color] = [
    PropertyColorMap[.brown]!.hex, PropertyColorMap[.lightBlue]!.hex, PropertyColorMap[.pink]!.hex,
    PropertyColorMap[.orange]!.hex, PropertyColorMap[.red]!.hex, PropertyColorMap[.yellow]!.hex,
    PropertyColorMap[.green]!.hex, PropertyColorMap[.darkBlue]!.hex, PropertyColorMap[.railroad]!.hex,
    PropertyColorMap[.utility]!.hex,
]

struct RainbowBarView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<rainbowColors.count, id: \.self) { i in
                Rectangle().fill(rainbowColors[i])
            }
        }
        .frame(height: 12)
    }
}

struct WildcardLayoutView: View {
    let card: GameCard
    var body: some View {
        if card.isMulticolorWild {
            VStack(spacing: 0) {
                RainbowBarView()
                Text("Property Wild Card")
                    .font(.interBlack(10))
                    .textCase(.uppercase)
                    .padding(4)
                RainbowBarView()
                Spacer(minLength: 0)
                Text("🎩").font(.system(size: 48))  // emoji glyph — keep system font
                Spacer(minLength: 0)
                Text("This card can be used as part of any property set. This card has no monetary value.")
                    .font(.interRegular(8))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(6)
            }
        } else {
            dualWildcard
        }
    }

    private var dualWildcard: some View {
        let isFlipped = card.activeColor == card.altColor
        let activeColor = isFlipped ? card.altColor! : card.color!
        let inactiveColor = isFlipped ? card.color! : card.altColor!
        let activeInfo = PropertyColorMap[activeColor]!
        let inactiveInfo = PropertyColorMap[inactiveColor]!
        let activeRents = GameConfig.rentTable[activeColor] ?? []
        let activeSetSize = GameConfig.setSize[activeColor] ?? activeRents.count
        let inactiveRents = GameConfig.rentTable[inactiveColor] ?? []
        let inactiveSetSize = GameConfig.setSize[inactiveColor] ?? inactiveRents.count

        return VStack(spacing: 0) {
            dualHeader(info: activeInfo)
            HStack(spacing: 0) {
                RentTableView(rents: inactiveRents, setSize: inactiveSetSize, color: inactiveInfo.hex, hideHeader: true, compact: true)
                    .rotationEffect(.degrees(180))
                RentTableView(rents: activeRents, setSize: activeSetSize, color: activeInfo.hex, hideHeader: true, compact: true)
            }
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity)
            .background(Color.white)
            dualHeader(info: inactiveInfo)
                .rotationEffect(.degrees(180))
        }
    }

    private func dualHeader(info: PropertyColorInfo) -> some View {
        VStack(spacing: 1) {
            Text("PROPERTY").font(.interBlack(7))
            Text("WILD CARD").font(.interBlack(10))
            Text("(Use card either way up.)").font(.interRegular(7)).opacity(0.8)
        }
        .foregroundColor(info.textColor)
        .shadow(color: textShadowColor(info.textColor), radius: 1, x: 0, y: 1)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(info.hex)
    }
}

// MARK: - Rent

struct RentLayoutView: View {
    let card: GameCard
    var body: some View {
        VStack(spacing: 4) {
            Text("ACTION CARD")
                .font(.interBlack(10))
                .tracking(1)
                .foregroundColor(.black.opacity(0.6))
                .padding(.top, 24)
            Spacer(minLength: 0)
            ring
            Spacer(minLength: 0)
            Text(card.isWildRent ? "Any color — charge 1 player" : "Charge all players")
                .font(.interRegular(8))
                .foregroundColor(.black.opacity(0.5))
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var ring: some View {
        ZStack {
            if card.isWildRent {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: rainbowColors + [rainbowColors[0]]), center: .center))
            } else {
                let colors = card.rentColors ?? []
                let hex1 = colors.first.flatMap { PropertyColorMap[$0]?.hex } ?? Color(hex: "#888")
                let hex2 = colors.count > 1 ? (PropertyColorMap[colors[1]]?.hex ?? Color(hex: "#888")) : Color(hex: "#888")
                VStack(spacing: 0) {
                    Rectangle().fill(hex1)
                    Rectangle().fill(hex2)
                }
                .clipShape(Circle())
            }
            Circle().stroke(Color(hex: "#222"), lineWidth: 3)
            Circle().fill(Color.white).frame(width: 66, height: 66)
            Text("RENT").font(.interBlack(16)).foregroundColor(Color(hex: "#222"))
        }
        .frame(width: 102, height: 102)
    }
}

// MARK: - Action

struct ActionLayoutView: View {
    let card: GameCard
    var body: some View {
        let kind = card.actionKind
        let meta: (title: String, desc: String) = kind?.meta ?? (title: card.name, desc: "")
        VStack(spacing: 4) {
            Text("ACTION CARD")
                .font(.interBlack(10))
                .tracking(1)
                .foregroundColor(.black.opacity(0.6))
                .padding(.top, 24)
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(Color.white)
                Circle().stroke(Color(hex: "#222"), lineWidth: 3)
                ovalContent(kind, meta.title)
                    .padding(8)
            }
            .frame(width: 102, height: 102)
            Spacer(minLength: 0)
            Text(meta.desc)
                .font(.interRegular(8))
                .foregroundColor(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func ovalContent(_ kind: ActionKind?, _ title: String) -> some View {
        switch kind {
        case .passGo:
            VStack(spacing: 0) {
                Text("PASS").font(.interBlack(14)).tracking(2)
                Text("GO").font(.interBlack(30)).tracking(3)
                Image("PassGo").resizable().scaledToFit().frame(width: 60)
            }
            .foregroundColor(Color(hex: "#222"))
        case .house:
            VStack(spacing: 0) {
                Image("House").resizable().scaledToFit().frame(width: 50)
                Text("HOUSE").font(.interBlack(16))
            }
            .foregroundColor(Color(hex: "#222"))
        case .hotel:
            VStack(spacing: 0) {
                Image("Hotel").resizable().scaledToFit().frame(width: 50)
                Text("HOTEL").font(.interBlack(16))
            }
            .foregroundColor(Color(hex: "#222"))
        case .itsMyBirthday:
            VStack(spacing: 2) {
                Text("IT'S MY").font(.interBlack(11)).tracking(1)
                Text("BIRTHDAY").font(.interBlack(13)).tracking(1)
                Image("Birthday").resizable().scaledToFit().frame(width: 40)
            }
            .foregroundColor(Color(hex: "#222"))
        case .debtCollector:
            Text(title)
                .font(.interBlack(12))
                .foregroundColor(Color(hex: "#222"))
                .multilineTextAlignment(.center)
        default:
            Text(title)
                .font(.interBlack(16))
                .foregroundColor(Color(hex: "#222"))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Rent table

struct RentTableView: View {
    let rents: [Int]
    let setSize: Int
    let color: Color
    var hideHeader: Bool = false
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: compact ? 0.5 : 2) {
            if !hideHeader {
                Text("RENT")
                    .font(.interBlack(13))
                    .foregroundColor(Color(hex: "#999"))
                    .padding(.bottom, 2)
            }
            ForEach(Array(rents.dropFirst().enumerated()), id: \.offset) { i, rent in
                let n = i + 1
                let full = n == setSize
                HStack(spacing: compact ? 4 : 8) {
                    RentIconView(count: n, color: color)
                        .frame(width: compact ? 20 : 29, height: compact ? 16 : 23)
                    Text("◆\(rent)")
                        .font(.interBold(compact ? 10 : 13))
                        .foregroundColor(full ? Color(hex: "#c62828") : Color(hex: "#555"))
                }
            }
        }
    }
}
