import XCTest
@testable import JeffopolyDeal

@MainActor
final class SpyHaptics: HapticPerforming {
    private(set) var performed: [HapticEvent] = []
    func perform(_ event: HapticEvent) { performed.append(event) }
}

@MainActor
final class GameBridgeTests: XCTestCase {
    private var haptics: SpyHaptics!
    private var bridge: GameBridge!

    override func setUp() {
        super.setUp()
        haptics = SpyHaptics()
        bridge = GameBridge(haptics: haptics)
    }

    private func message(
        type: String = "haptic",
        event: String? = "cardPlayed",
        id: String? = nil,
        version: Int = GameBridge.supportedVersion
    ) -> [String: Any] {
        var body: [String: Any] = ["v": version, "type": type]
        if let event { body["payload"] = ["event": event] }
        if let id { body["id"] = id }
        return body
    }

    // MARK: - Routing

    func testPerformsEveryEventInTheVocabulary() {
        for event in HapticEvent.allCases {
            let outcome = bridge.handle(message(event: event.rawValue, id: event.rawValue))
            XCTAssertEqual(outcome, .performed(event))
        }
        XCTAssertEqual(haptics.performed, HapticEvent.allCases)
    }

    // MARK: - Deduplication

    func testASingleGameEventProducesAtMostOneHaptic() {
        XCTAssertEqual(bridge.handle(message(id: "action:7")), .performed(.cardPlayed))
        XCTAssertEqual(bridge.handle(message(id: "action:7")), .ignoredDuplicate)
        XCTAssertEqual(haptics.performed, [.cardPlayed])
    }

    func testDistinctIdsAreNotConfused() {
        bridge.handle(message(id: "action:7"))
        bridge.handle(message(id: "action:8"))
        XCTAssertEqual(haptics.performed, [.cardPlayed, .cardPlayed])
    }

    func testMessagesWithoutAnIdAreNotDeduplicated() {
        bridge.handle(message(event: "selection"))
        bridge.handle(message(event: "selection"))
        XCTAssertEqual(haptics.performed, [.selection, .selection])
    }

    // MARK: - Validation

    func testRejectsAnUnsupportedVersion() {
        XCTAssertEqual(bridge.handle(message(version: 99)), .ignoredUnsupportedVersion(99))
        XCTAssertTrue(haptics.performed.isEmpty)
    }

    func testRejectsAnUnknownEventRatherThanGuessing() {
        XCTAssertEqual(
            bridge.handle(message(event: "summonDemon")),
            .ignoredUnknownEvent("summonDemon")
        )
        XCTAssertTrue(haptics.performed.isEmpty)
    }

    func testIgnoresReservedTypesThatNothingConsumesYet() {
        XCTAssertEqual(bridge.handle(message(type: "lifecycle")), .ignoredUnknownType("lifecycle"))
        XCTAssertEqual(bridge.handle(message(type: "somethingNewer")), .ignoredUnknownType("somethingNewer"))
        XCTAssertTrue(haptics.performed.isEmpty)
    }

    func testRejectsMalformedBodies() {
        let malformed: [Any] = [
            "just a string",
            42,
            [String: Any](),
            ["type": "haptic"],                                   // no version
            ["v": GameBridge.supportedVersion],                   // no type
            ["v": "1", "type": "haptic"],                         // version wrong shape
            ["v": GameBridge.supportedVersion, "type": "haptic"], // no payload
            ["v": GameBridge.supportedVersion, "type": "haptic", "payload": "nope"],
            ["v": GameBridge.supportedVersion, "type": "haptic", "payload": [String: Any]()],
        ]
        for body in malformed {
            let outcome = bridge.handle(body)
            XCTAssertTrue(
                outcome == .ignoredMalformed,
                "expected \(body) to be rejected as malformed, got \(outcome)"
            )
        }
        XCTAssertTrue(haptics.performed.isEmpty)
    }

    func testAnInvalidMessageWithAnIdDoesNotBlockALaterValidOne() {
        // The id is remembered before routing, so a malformed payload must not
        // poison a subsequent retry of the same event.
        bridge.handle(["v": GameBridge.supportedVersion, "type": "haptic", "id": "x", "payload": "bad"])
        XCTAssertEqual(bridge.handle(message(id: "y")), .performed(.cardPlayed))
    }
}

@MainActor
final class GameBridgeContextTests: XCTestCase {
    private var bridge: GameBridge!
    private var contexts: [GameBridge.GameContext] = []

    override func setUp() {
        super.setUp()
        contexts = []
        bridge = GameBridge(haptics: SpyHaptics())
        bridge.onGameContext = { [weak self] in self?.contexts.append($0) }
    }

    private func context(_ payload: [String: Any]) -> GameBridge.GameContext? {
        bridge.handle(["v": GameBridge.supportedVersion, "type": "gameContext", "payload": payload])
        return contexts.last
    }

    func testReportsALobbySoTheShellCanAdvertiseIt() {
        let result = context(["gameCode": "abcd", "phase": "Lobby", "hostName": "Jeff"])
        XCTAssertEqual(result?.gameCode, "ABCD")
        XCTAssertTrue(result?.isLobby == true)
        XCTAssertEqual(result?.hostName, "Jeff")
    }

    func testAGameInPlayIsNotALobby() {
        XCTAssertFalse(context(["gameCode": "ABCD", "phase": "Play"])?.isLobby == true)
    }

    func testLeavingReportsNoGame() {
        let result = context(["gameCode": NSNull(), "phase": NSNull()])
        XCTAssertNil(result?.gameCode)
        XCTAssertFalse(result?.isLobby == true)
    }

    func testCarriesIdentitySoNotificationsCanRouteBack() {
        let result = context(["gameCode": "ABCD", "phase": "Lobby", "playerId": "PID", "playerName": "Jeff"])
        XCTAssertEqual(result?.playerId, "PID")
        XCTAssertEqual(result?.playerName, "Jeff")
    }

    func testRejectsAPayloadThatIsNotAnObject() {
        bridge.handle(["v": GameBridge.supportedVersion, "type": "gameContext", "payload": "nope"])
        XCTAssertTrue(contexts.isEmpty)
    }
}
