import Foundation
import SignalRClient

/// Mirrors src/web/pages/gamePage/GameSignalRClient.ts 1:1 — same method names,
/// same "gameStateUpdated" push event, same reconnect→RejoinGame handshake.
@MainActor
final class GameHubClient: ObservableObject {
    @Published private(set) var state: GameState?
    @Published private(set) var isConnected: Bool = false

    private let connection: HubConnection
    private var delegateBox: DelegateBox!
    private var startContinuation: CheckedContinuation<Void, Error>?

    private(set) var gameCode: String = ""
    private(set) var playerName: String = ""
    private(set) var playerId: String = ""

    nonisolated static var defaultHubURL: URL {
        #if DEBUG
        // iOS Simulator can reach the host machine's localhost directly.
        return URL(string: "http://localhost:5010/hub/game")!
        #else
        return URL(string: "https://jeffopolydeal.azurewebsites.net/hub/game")!
        #endif
    }

    init(baseURL: URL = GameHubClient.defaultHubURL) {
        connection = HubConnectionBuilder(url: baseURL)
            .withJSONHubProtocol()
            .withAutoReconnect()
            .build()

        delegateBox = DelegateBox(owner: self)
        connection.delegate = delegateBox

        connection.on(method: "gameStateUpdated") { [weak self] (newState: GameState) in
            Task { @MainActor in self?.state = newState }
        }
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.startContinuation = continuation
            connection.start()
        }
    }

    func stop() {
        connection.stop()
    }

    var connectionId: String? { connection.connectionId }

    // MARK: - Hub methods (see src/JeffopolyDeal.Game/Hubs/GameHub.cs)

    func createGame(fixedCode: String? = nil, themeName: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            connection.invoke(method: "CreateGame", fixedCode, themeName, resultType: String.self) { result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result ?? "")
            }
        }
    }

    func joinGame(gameCode: String, playerName: String, playerId: String) async throws {
        self.gameCode = gameCode
        self.playerName = playerName
        self.playerId = playerId
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "JoinGame", gameCode, playerName, playerId) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    @discardableResult
    func rejoinGame(gameCode: String, playerName: String, playerId: String) async throws -> Bool {
        self.gameCode = gameCode
        self.playerName = playerName
        self.playerId = playerId
        return try await withCheckedThrowingContinuation { continuation in
            connection.invoke(method: "RejoinGame", gameCode, playerName, playerId, resultType: Bool.self) { result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result ?? false)
            }
        }
    }

    func addBotPlayer(gameCode: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "AddBotPlayer", gameCode) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func startGame(gameCode: String, allowSinglePlayer: Bool = false, populateBoards: Bool = false, addBots: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "StartGame", gameCode, allowSinglePlayer, populateBoards, addBots) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func drawCards() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "DrawCards") { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func playCard(cardId: Int, request: PlayCardRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "PlayCard", cardId, request) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func endTurn() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "EndTurn") { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func discardCard(cardId: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "DiscardCard", cardId) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func cancelDiscard() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "CancelDiscard") { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func respondToAction(_ response: ActionResponse) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "RespondToAction", response) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func getDebugDeckInfo() async throws -> DebugDeckInfo? {
        try await withCheckedThrowingContinuation { continuation in
            connection.invoke(method: "GetDebugDeckInfo", resultType: DebugDeckInfo.self) { result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result)
            }
        }
    }

    func flipWildcard(cardId: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "FlipWildcard", cardId) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func moveProperty(cardId: Int, targetSetId: Int, targetColor: PropertyColor?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "MoveProperty", cardId, targetSetId, targetColor?.rawValue) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func endGame() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.invoke(method: "EndGame") { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func debugCommand(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            connection.invoke(method: "DebugCommand", command, resultType: String.self) { result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result ?? "")
            }
        }
    }

    // MARK: - Connection lifecycle

    fileprivate func handleConnectionOpen() {
        isConnected = true
        startContinuation?.resume()
        startContinuation = nil
    }

    fileprivate func handleConnectionFailedToOpen(error: Error) {
        isConnected = false
        startContinuation?.resume(throwing: error)
        startContinuation = nil
    }

    fileprivate func handleConnectionClose() {
        isConnected = false
    }

    fileprivate func handleReconnected() {
        isConnected = true
        guard !gameCode.isEmpty, !playerName.isEmpty, !playerId.isEmpty else { return }
        Task {
            _ = try? await self.rejoinGame(gameCode: self.gameCode, playerName: self.playerName, playerId: self.playerId)
        }
    }

    /// HubConnectionDelegate's requirements aren't actor-isolated, so this indirection box
    /// (rather than GameHubClient itself conforming) keeps every hop onto @MainActor explicit.
    private final class DelegateBox: HubConnectionDelegate {
        weak var owner: GameHubClient?
        init(owner: GameHubClient) { self.owner = owner }

        func connectionDidOpen(hubConnection: HubConnection) {
            Task { @MainActor in self.owner?.handleConnectionOpen() }
        }
        func connectionDidFailToOpen(error: Error) {
            Task { @MainActor in self.owner?.handleConnectionFailedToOpen(error: error) }
        }
        func connectionDidClose(error: Error?) {
            Task { @MainActor in self.owner?.handleConnectionClose() }
        }
        func connectionWillReconnect(error: Error) {
            Task { @MainActor in self.owner?.handleConnectionClose() }
        }
        func connectionDidReconnect() {
            Task { @MainActor in self.owner?.handleReconnected() }
        }
    }
}
