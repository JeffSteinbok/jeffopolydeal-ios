import Foundation
import OSLog
import WebKit

/// Receives semantic events from the embedded React client.
///
/// The contract is deliberately narrow: the client reports *what happened in
/// the game*, and the shell decides what that should feel like. Anything
/// malformed, from an unsupported version, or already seen is dropped rather
/// than guessed at — a bad message must never reach a feedback generator.
///
/// Mirrors src/web/utilities/NativeBridge.ts; the two must stay in sync.
@MainActor
final class GameBridge: NSObject, WKScriptMessageHandler {
    /// Handler name the client posts to. Mirrors `BRIDGE_HANDLER_NAME`.
    static let handlerName = "jeffopoly"

    /// Envelope version this shell understands. Mirrors `BRIDGE_VERSION`.
    static let supportedVersion = 1

    /// What the bridge did with a message. Returned so the routing is testable
    /// without constructing a `WKScriptMessage`, which has no public initialiser.
    /// What game the client is in, as far as the shell needs to know. Not
    /// gameplay state — the shell has no business interpreting a board.
    struct GameContext: Equatable {
        /// Nil once the player leaves, which is the cue to stop advertising.
        let gameCode: String?
        let phase: String?
        let playerId: String?
        let playerName: String?
        /// Whoever created the game, shown to nearby devices.
        let hostName: String?

        var isLobby: Bool { phase == "Lobby" && gameCode != nil }
    }

    enum Outcome: Equatable {
        case performed(HapticEvent)
        case contextChanged(GameContext)
        case ignoredDuplicate
        case ignoredUnsupportedVersion(Int)
        case ignoredUnknownType(String)
        case ignoredUnknownEvent(String)
        case ignoredMalformed
    }

    private static let log = Logger(subsystem: "net.steinbok.jeffopolydeal", category: "bridge")

    /// Called when the client reports a change of game. Set by the host view.
    var onGameContext: ((GameContext) -> Void)?

    private let haptics: HapticPerforming
    private var seenIds: Set<String> = []
    private var seenOrder: [String] = []
    private static let maxRememberedIds = 500

    init(haptics: HapticPerforming) {
        self.haptics = haptics
        super.init()
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let body = message.body
        Task { @MainActor in _ = self.handle(body) }
    }

    /// Validates and routes one message body.
    @discardableResult
    func handle(_ body: Any) -> Outcome {
        let outcome = route(body)
        switch outcome {
        case .performed(let event):
            Self.log.debug("performed \(event.rawValue, privacy: .public)")
        case .contextChanged(let context):
            Self.log.debug("game context \(context.gameCode ?? "none", privacy: .public) \(context.phase ?? "-", privacy: .public)")
        case .ignoredDuplicate:
            break // Expected and frequent; not worth a line.
        case .ignoredUnsupportedVersion(let version):
            Self.log.error("dropped message from unsupported bridge version \(version)")
        case .ignoredUnknownType(let type):
            Self.log.notice("ignored unhandled message type \(type, privacy: .public)")
        case .ignoredUnknownEvent(let name):
            Self.log.error("dropped unknown haptic event \(name, privacy: .public)")
        case .ignoredMalformed:
            Self.log.error("dropped malformed bridge message")
        }
        return outcome
    }

    private func route(_ body: Any) -> Outcome {
        guard let envelope = body as? [String: Any],
              let version = envelope["v"] as? Int,
              let type = envelope["type"] as? String
        else { return .ignoredMalformed }

        guard version == Self.supportedVersion else {
            return .ignoredUnsupportedVersion(version)
        }

        // The client already deduplicates, but a shell that trusts the page to
        // get that right is one re-render away from buzzing twice.
        if let id = envelope["id"] as? String {
            guard !seenIds.contains(id) else { return .ignoredDuplicate }
            remember(id)
        }

        switch type {
        case "haptic":
            return routeHaptic(envelope["payload"])
        case "gameContext":
            return routeGameContext(envelope["payload"])
        case "lifecycle":
            // Reserved by the contract; nothing consumes it yet.
            return .ignoredUnknownType(type)
        default:
            return .ignoredUnknownType(type)
        }
    }

    private func routeHaptic(_ payload: Any?) -> Outcome {
        guard let payload = payload as? [String: Any],
              let name = payload["event"] as? String
        else { return .ignoredMalformed }

        guard let event = HapticEvent(rawValue: name) else {
            return .ignoredUnknownEvent(name)
        }

        haptics.perform(event)
        return .performed(event)
    }

    private func routeGameContext(_ payload: Any?) -> Outcome {
        guard let payload = payload as? [String: Any] else { return .ignoredMalformed }

        // Every field is optional: leaving a game reports nothing but nils.
        let context = GameContext(
            gameCode: (payload["gameCode"] as? String)?.uppercased(),
            phase: payload["phase"] as? String,
            playerId: payload["playerId"] as? String,
            playerName: payload["playerName"] as? String,
            hostName: payload["hostName"] as? String
        )
        onGameContext?(context)
        return .contextChanged(context)
    }

    private func remember(_ id: String) {
        seenIds.insert(id)
        seenOrder.append(id)
        guard seenOrder.count > Self.maxRememberedIds else { return }
        let staleCount = seenOrder.count - Self.maxRememberedIds
        for stale in seenOrder.prefix(staleCount) { seenIds.remove(stale) }
        seenOrder.removeFirst(staleCount)
    }
}
