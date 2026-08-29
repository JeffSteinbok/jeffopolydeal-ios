import XCTest
@testable import JeffopolyDeal

final class GameWebURLTests: XCTestCase {
    private let base = URL(string: "https://jeffopolydeal.example.com")!

    private func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    // MARK: - Building

    func testJoinURLCarriesIdentityAndCode() {
        let url = GameWebURL.entry(
            baseURL: base, gameCode: "abcd", playerName: "  Jeff  ",
            playerId: "PID", isRejoin: false
        )
        XCTAssertEqual(url.path(), "/play")
        XCTAssertEqual(query(url), [
            "v": GameWebURL.contractVersion,
            "host": "ios",
            "pid": "PID",
            "name": "Jeff",
            "game": "ABCD",
        ])
    }

    func testEmptyCodeAsksForANewGame() {
        let url = GameWebURL.entry(
            baseURL: base, gameCode: "   ", playerName: "Jeff",
            playerId: "PID", isRejoin: true
        )
        XCTAssertEqual(query(url)["new"], "1")
        XCTAssertNil(query(url)["game"], "a create must not also carry a code")
        XCTAssertNil(query(url)["rejoin"], "there is nothing to rejoin yet")
    }

    func testRejoinIsFlaggedForAnExistingGame() {
        let url = GameWebURL.entry(
            baseURL: base, gameCode: "ABCD", playerName: "Jeff",
            playerId: "PID", isRejoin: true
        )
        XCTAssertEqual(query(url)["rejoin"], "1")
    }

    func testNamesNeedingEncodingSurviveTheRoundTrip() {
        let url = GameWebURL.entry(
            baseURL: base, gameCode: "ABCD", playerName: "Jeff & Sons?",
            playerId: "PID", isRejoin: false
        )
        XCTAssertEqual(query(url)["name"], "Jeff & Sons?")
    }

    // MARK: - Classifying

    func testRecognisesTheGameplaySurface() {
        let url = URL(string: "https://jeffopolydeal.example.com/play?v=1&game=ABCD")!
        XCTAssertTrue(GameWebURL.isGameplay(url, baseURL: base))
        XCTAssertFalse(GameWebURL.isShellRoot(url, baseURL: base))
    }

    func testRecognisesTheShellRootAsTheLeaveSignal() {
        for candidate in ["https://jeffopolydeal.example.com", "https://jeffopolydeal.example.com/"] {
            let url = URL(string: candidate)!
            XCTAssertTrue(GameWebURL.isShellRoot(url, baseURL: base), candidate)
            XCTAssertFalse(GameWebURL.isGameplay(url, baseURL: base), candidate)
        }
    }

    func testTreatsOtherOriginsAsExternal() {
        for candidate in [
            "https://github.com/JeffSteinbok/jeffopolydeal",
            "https://evil.example.com/play?v=1&game=ABCD",
            "http://jeffopolydeal.example.com.attacker.net/play",
        ] {
            let url = URL(string: candidate)!
            XCTAssertFalse(GameWebURL.isGameplay(url, baseURL: base), candidate)
            XCTAssertFalse(GameWebURL.isShellRoot(url, baseURL: base), candidate)
        }
    }

    func testIgnoresNonWebSchemesOnOurOwnHost() {
        let url = URL(string: "javascript://jeffopolydeal.example.com/play")!
        XCTAssertFalse(GameWebURL.isSameOrigin(url, baseURL: base))
    }

    // MARK: - Reading back the resolved code

    func testReadsTheCodeTheServerAssigned() {
        let url = URL(string: "https://jeffopolydeal.example.com/play?v=1&host=ios&game=xnue")!
        XCTAssertEqual(GameWebURL.gameCode(in: url, baseURL: base), "XNUE")
    }

    func testIgnoresACodeThatIsNotAGameCode() {
        for candidate in [
            "https://jeffopolydeal.example.com/play?v=1&game=AB",
            "https://jeffopolydeal.example.com/play?v=1&game=TOOLONG",
            "https://jeffopolydeal.example.com/play?v=1&game=AB!D",
            "https://jeffopolydeal.example.com/play?v=1&new=1",
            "https://jeffopolydeal.example.com/?game=ABCD",
        ] {
            XCTAssertNil(GameWebURL.gameCode(in: URL(string: candidate)!, baseURL: base), candidate)
        }
    }

    func testRoundTripsAJoinURLBackToItsCode() {
        let url = GameWebURL.entry(
            baseURL: base, gameCode: "WXYZ", playerName: "Jeff",
            playerId: "PID", isRejoin: false
        )
        XCTAssertEqual(GameWebURL.gameCode(in: url, baseURL: base), "WXYZ")
    }
}
