import Foundation

// Mirrors src/web/Types.ts (everything below Card/PropertyColor, which live in CardModel.swift).
// Server serializes with JsonNamingPolicy.CamelCase + JsonStringEnumConverter
// (Program.cs:49-57), so these Codable structs use matching camelCase property
// names and String-raw enums with no custom CodingKeys needed.

enum GamePhase: String, Codable {
    case lobby = "Lobby"
    case draw = "Draw"
    case play = "Play"
    case awaitingResponse = "AwaitingResponse"
    case discard = "Discard"
    case gameOver = "GameOver"
}

enum PendingActionType: String, Codable {
    case payRent = "PayRent"
    case payDebtCollector = "PayDebtCollector"
    case payBirthday = "PayBirthday"
    case respondToSlyDeal = "RespondToSlyDeal"
    case respondToForceDeal = "RespondToForceDeal"
    case respondToDealBreaker = "RespondToDealBreaker"
    case justSayNoChain = "JustSayNoChain"
}

struct PropertySetState: Codable, Identifiable, Hashable {
    var setId: Int
    var color: PropertyColor
    var cards: [GameCard]
    var isComplete: Bool
    var hasHouse: Bool
    var hasHotel: Bool
    var rent: Int
    var requiredSize: Int

    var id: Int { setId }
}

struct PlayerState: Codable, Identifiable, Hashable {
    var playerId: String
    var connectionId: String
    var name: String
    var handCount: Int
    var isConnected: Bool
    var hand: [GameCard]? = nil
    var bank: [GameCard]
    var propertySets: [PropertySetState]
    var unboundWilds: [GameCard]
    var completedSetCount: Int
    var uniqueCompletedSetCount: Int

    var id: String { playerId }
}

struct PendingAction: Codable, Hashable {
    var type: PendingActionType
    var sourcePlayerId: String
    var sourcePlayerName: String
    var targetPlayerIds: [String] // SignalR connectionIds, not stable playerIds
    var amount: Int
    var targetCardId: Int? = nil
    var targetCardName: String? = nil
    var offeredCardId: Int? = nil
    var offeredCardName: String? = nil
    var targetSetColor: PropertyColor? = nil
    var justSayNoResponderId: String? = nil
}

struct GameAction: Codable, Identifiable, Hashable {
    var id: Int
    var playerName: String
    var text: String
    var cardPlayed: GameCard? = nil
    var targetPlayerName: String? = nil
    var sourceCards: [GameCard]? = nil
    var targetCards: [GameCard]? = nil
    var persistent: Bool? = nil
}

/// setSize/rentTable are kept as raw String-keyed dictionaries (rather than
/// [PropertyColor: Int]) since System.Text.Json's CamelCase policy does not
/// rewrite dictionary keys — the wire keys are the enum's exact raw values
/// ("Brown", "LightBlue", ...), which line up with PropertyColor.rawValue.
struct GameConfigData: Codable, Hashable {
    var setSize: [String: Int]
    var rentTable: [String: [Int]]

    func setSize(for color: PropertyColor) -> Int { setSize[color.rawValue] ?? 0 }
    func rentTable(for color: PropertyColor) -> [Int] { rentTable[color.rawValue] ?? [] }
}

struct GameState: Codable {
    var phase: GamePhase
    var gameCode: String
    var players: [PlayerState]
    var currentPlayerIndex: Int
    var playsUsed: Int
    var drawPileCount: Int
    var discardPileCount: Int
    var topDiscard: GameCard? = nil
    var pendingAction: PendingAction? = nil
    var winnerId: String? = nil
    var winnerName: String? = nil
    var paymentError: String? = nil
    var recentActions: [GameAction]
    var gameConfig: GameConfigData? = nil
}

// MARK: - Outgoing request payloads (Encodable, sent via GameHubClient)

struct PlayCardRequest: Encodable {
    var playAsMoney: Bool
    var wildcardColor: PropertyColor? = nil
    var rentColor: PropertyColor? = nil
    var targetPlayerId: String? = nil
    var targetCardId: Int? = nil
    var offeredCardId: Int? = nil
    var targetSetColor: PropertyColor? = nil
    var doubleRentCardIds: [Int]? = nil
}

struct ActionResponse: Encodable {
    var playJustSayNo: Bool
    var paymentCardIds: [Int]? = nil
}

// MARK: - Debug (GetDebugDeckInfo) — low priority, included for hub-surface completeness

struct DebugPlayerHand: Codable {
    var playerName: String
    var cards: [GameCard]
}

struct DebugDeckInfo: Codable {
    var drawPile: [GameCard]
    var discardPile: [GameCard]
    var playerHands: [DebugPlayerHand]
}
