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

    func testStartURLCarriesOnlyTheHostAndNameHint() {
        let url = GameWebURL.start(baseURL: base, playerNameHint: "  Jeff's iPhone  ")
        XCTAssertEqual(query(url), [
            "v": GameWebURL.contractVersion,
            "host": "ios",
            "name": "Jeff's iPhone",
        ])
    }

    func testStartURLOmitsAnAbsentOrBlankNameHint() {
        XCTAssertNil(query(GameWebURL.start(baseURL: base, playerNameHint: nil))["name"])
        XCTAssertNil(query(GameWebURL.start(baseURL: base, playerNameHint: "   "))["name"])
    }

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
    }

    func testTreatsOurOwnStartPageAsInternal() {
        // The client owns the start page now, so navigating back to it must not
        // be mistaken for a link leaving the app.
        for candidate in ["https://jeffopolydeal.example.com", "https://jeffopolydeal.example.com/"] {
            XCTAssertTrue(GameWebURL.isSameOrigin(URL(string: candidate)!, baseURL: base), candidate)
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
            XCTAssertFalse(GameWebURL.isSameOrigin(url, baseURL: base), candidate)
        }
    }

    func testIgnoresNonWebSchemesOnOurOwnHost() {
        let url = URL(string: "javascript://jeffopolydeal.example.com/play")!
        XCTAssertFalse(GameWebURL.isSameOrigin(url, baseURL: base))
    }

    // MARK: - Shared invite links

    func testReadsTheCodeFromASharedInvite() {
        let url = URL(string: "https://jeffopolydeal.example.com/?join=abcd")!
        XCTAssertEqual(GameWebURL.sharedGameCode(in: url, baseURL: base), "ABCD")
    }

    func testIgnoresAnInviteFromAnotherSite() {
        let url = URL(string: "https://evil.example.com/?join=ABCD")!
        XCTAssertNil(GameWebURL.sharedGameCode(in: url, baseURL: base))
    }

    func testIgnoresALinkWithNoUsableCode() {
        for candidate in [
            "https://jeffopolydeal.example.com/",
            "https://jeffopolydeal.example.com/?join=",
            "https://jeffopolydeal.example.com/?join=AB",
            "https://jeffopolydeal.example.com/?join=AB!D",
            "https://jeffopolydeal.example.com/?game=ABCD",
        ] {
            XCTAssertNil(GameWebURL.sharedGameCode(in: URL(string: candidate)!, baseURL: base), candidate)
        }
    }
}
