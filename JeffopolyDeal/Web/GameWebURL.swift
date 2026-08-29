import Foundation

/// The gameplay entry contract, shared with the React client's
/// `src/web/utilities/NativeHost.ts` in the JeffSteinbok/jeffopolydeal repo.
///
/// The native shell owns app entry and player identity; the web client owns
/// gameplay and the SignalR connection. Everything the client needs to open the
/// right game travels in this URL, so there is no second gameplay state store.
enum GameWebURL {
    /// Served by `MapFallbackToFile("index.html")` in the backend's Program.cs.
    static let entryPath = "play"

    /// Bumped when the query-string shape changes incompatibly.
    static let contractVersion = "1"

    static let hostIdentifier = "ios"

    /// Appended to the web view's User-Agent so server-side telemetry can tell
    /// app traffic from browser and PWA traffic. Both now reach the hub through
    /// the same JavaScript client, so nothing else distinguishes them.
    static let userAgentSuffix = "JeffopolyDeal-iOS"

    /// Gameplay URL for `gameCode`. An empty code asks the server for a new game.
    static func entry(
        baseURL: URL = AppConfiguration.baseURL,
        gameCode: String,
        playerName: String,
        playerId: String,
        isRejoin: Bool
    ) -> URL {
        let code = gameCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var items = [
            URLQueryItem(name: "v", value: contractVersion),
            URLQueryItem(name: "host", value: hostIdentifier),
            URLQueryItem(name: "pid", value: playerId),
            URLQueryItem(name: "name", value: playerName.trimmingCharacters(in: .whitespacesAndNewlines)),
        ]

        if code.isEmpty {
            items.append(URLQueryItem(name: "new", value: "1"))
        } else {
            items.append(URLQueryItem(name: "game", value: code))
            if isRejoin {
                items.append(URLQueryItem(name: "rejoin", value: "1"))
            }
        }

        return baseURL.appending(path: entryPath).appending(queryItems: items)
    }

    /// True when `url` is the embedded gameplay surface on our own server.
    static func isGameplay(_ url: URL, baseURL: URL = AppConfiguration.baseURL) -> Bool {
        isSameOrigin(url, baseURL: baseURL)
            && normalizedPath(url) == normalizedPath(baseURL.appending(path: entryPath))
    }

    /// True when `url` is our site root. The web client navigates there to say
    /// "this player left the game", which is the shell's cue to pop to StartView.
    static func isShellRoot(_ url: URL, baseURL: URL = AppConfiguration.baseURL) -> Bool {
        isSameOrigin(url, baseURL: baseURL) && normalizedPath(url) == normalizedPath(baseURL)
    }

    static func isSameOrigin(_ url: URL, baseURL: URL = AppConfiguration.baseURL) -> Bool {
        guard
            let host = url.host()?.lowercased(),
            let baseHost = baseURL.host()?.lowercased(),
            let scheme = url.scheme?.lowercased()
        else { return false }
        return host == baseHost && ["http", "https"].contains(scheme)
    }

    /// The game code the client is currently showing. After a create, the client
    /// rewrites its own URL with the code the server assigned, which is how the
    /// shell learns the code it needs to persist a rejoin session.
    static func gameCode(in url: URL, baseURL: URL = AppConfiguration.baseURL) -> String? {
        guard
            isGameplay(url, baseURL: baseURL),
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            let code = items.first(where: { $0.name == "game" })?.value?.uppercased(),
            code.count == 4,
            code.allSatisfy({ $0.isLetter || $0.isNumber })
        else { return nil }
        return code
    }

    private static func normalizedPath(_ url: URL) -> String {
        var path = url.path()
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path.isEmpty ? "/" : path
    }
}
