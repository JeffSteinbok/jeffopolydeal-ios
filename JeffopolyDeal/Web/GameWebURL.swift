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

    /// Where the shell starts the client: the web start page. The client owns
    /// create, join, and the lobby; the shell contributes only the device name
    /// as a hint for the name field, and nearby games over the bridge.
    static func start(baseURL: URL = AppConfiguration.baseURL, playerNameHint: String? = nil) -> URL {
        var items = [
            URLQueryItem(name: "v", value: contractVersion),
            URLQueryItem(name: "host", value: hostIdentifier),
        ]
        if let hint = playerNameHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            items.append(URLQueryItem(name: "name", value: hint))
        }
        return baseURL.appending(queryItems: items)
    }

    /// Direct entry into one game, for a shared link or a notification tap.
    /// An empty code asks the server for a new game.
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

    static func isSameOrigin(_ url: URL, baseURL: URL = AppConfiguration.baseURL) -> Bool {
        guard
            let host = url.host()?.lowercased(),
            let baseHost = baseURL.host()?.lowercased(),
            let scheme = url.scheme?.lowercased()
        else { return false }
        return host == baseHost && ["http", "https"].contains(scheme)
    }

    /// The game code in a shared invite link, e.g. https://host/?join=ABCD.
    /// Returns nil for a link to somewhere else, or to another site entirely.
    static func sharedGameCode(in url: URL, baseURL: URL = AppConfiguration.baseURL) -> String? {
        guard
            isSameOrigin(url, baseURL: baseURL),
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            let code = items.first(where: { $0.name.lowercased() == "join" })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
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
