import Foundation

// Mirrors src/web/Types.ts Card shape.

enum GameCardType: String, Codable {
    case money = "Money"
    case property = "Property"
    case propertyWildcard = "PropertyWildcard"
    case rent = "Rent"
    case action = "Action"
}

enum PropertyColor: String, CaseIterable, Hashable, Codable {
    case brown = "Brown"
    case lightBlue = "LightBlue"
    case pink = "Pink"
    case orange = "Orange"
    case red = "Red"
    case yellow = "Yellow"
    case green = "Green"
    case darkBlue = "DarkBlue"
    case railroad = "Railroad"
    case utility = "Utility"
}

enum ActionKind: String, Codable {
    case passGo = "PassGo"
    case debtCollector = "DebtCollector"
    case itsMyBirthday = "ItsMyBirthday"
    case slyDeal = "SlyDeal"
    case forceDeal = "ForceDeal"
    case dealBreaker = "DealBreaker"
    case justSayNo = "JustSayNo"
    case doubleTheRent = "DoubleTheRent"
    case house = "House"
    case hotel = "Hotel"

    var meta: (title: String, desc: String) {
        switch self {
        case .passGo: return ("Pass Go", "Draw 2 extra cards")
        case .debtCollector: return ("Debt Collector", "Any player pays you 5")
        case .itsMyBirthday: return ("It's My Birthday", "All players pay you 2")
        case .slyDeal: return ("Sly Deal", "Steal 1 property")
        case .forceDeal: return ("Forced Deal", "Swap properties with any player")
        case .dealBreaker: return ("Deal Breaker", "Steal a complete set!")
        case .justSayNo: return ("Just Say No!", "Cancel any action against you")
        case .doubleTheRent: return ("Double The Rent!", "Play with a rent card")
        case .house: return ("House", "+3 rent on a complete set")
        case .hotel: return ("Hotel", "+4 rent (needs house)")
        }
    }
}

struct GameCard: Codable, Identifiable, Hashable {
    var id: Int = 0
    var cardType: GameCardType
    var moneyValue: Int = 0
    var name: String = ""
    var color: PropertyColor? = nil
    var altColor: PropertyColor? = nil
    var isMulticolorWild: Bool = false
    var rentColors: [PropertyColor]? = nil
    var isWildRent: Bool = false
    var actionKind: ActionKind? = nil
    var activeColor: PropertyColor? = nil
    var isPlayable: Bool? = nil
}
