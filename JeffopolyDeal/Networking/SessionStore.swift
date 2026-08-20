import Foundation

/// Mirrors src/web/App.tsx's localStorage-backed identity/session persistence:
/// - a stable per-install playerId (UUID), created once and reused forever
/// - the in-progress game session {gameCode, playerName, playerId}, used on
///   launch to decide whether to attempt RejoinGame instead of showing StartView
struct Session: Codable, Equatable {
    var gameCode: String
    var playerName: String
    var playerId: String
}

enum SessionStore {
    private static let playerIdKey = "jeffopolydeal_playerId"
    private static let sessionKey = "jeffopolydeal_session"

    static var playerId: String {
        if let existing = UserDefaults.standard.string(forKey: playerIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: playerIdKey)
        return newId
    }

    static func loadSession() -> Session? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    static func saveSession(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: sessionKey)
    }

    static func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
