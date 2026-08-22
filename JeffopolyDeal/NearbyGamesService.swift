import MultipeerConnectivity
import UIKit

/// Lets nearby devices discover in-progress lobbies without typing a code.
/// This is discovery-only — no MCSession/peer connection is ever established;
/// the actual game still runs entirely over the existing SignalR hub once a
/// player taps a discovered game and it fills in the code. Every iOS device in
/// a lobby advertises its shared game code; joiners group those adverts into
/// one game over Bluetooth/local Wi-Fi.
@MainActor
final class NearbyGamesService: NSObject, ObservableObject {
    struct NearbyGame: Identifiable, Hashable {
        var id: String { gameCode }
        let hostName: String
        let gameCode: String
    }

    @Published private(set) var nearbyGames: [NearbyGame] = []

    /// 1-15 chars, lowercase letters/numbers/hyphens only (MCNearbyServiceAdvertiser requirement).
    private static let serviceType = "jeffopolydl"

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var gamesByPeer: [MCPeerID: NearbyGame] = [:]

    // MARK: - Host side

    func startAdvertising(gameCode: String, hostName: String) {
        stopAdvertising()
        let info = ["code": gameCode, "host": hostName]
        let adv = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: Self.serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Joiner side

    func startBrowsing() {
        stopBrowsing()
        let br = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        gamesByPeer = [:]
        nearbyGames = []
    }

    private func refreshNearbyGames() {
        nearbyGames = Dictionary(grouping: gamesByPeer.values, by: \.gameCode)
            .values
            .compactMap(\.first)
            .sorted { $0.gameCode < $1.gameCode }
    }
}

extension NearbyGamesService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(false, nil) // discovery-only — never actually connect
    }
}

extension NearbyGamesService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let advertisedCode = info?["code"] else { return }
        let code = advertisedCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        let host = info?["host"] ?? peerID.displayName
        Task { @MainActor in
            self.gamesByPeer[peerID] = NearbyGame(hostName: host, gameCode: code)
            self.refreshNearbyGames()
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.gamesByPeer.removeValue(forKey: peerID)
            self.refreshNearbyGames()
        }
    }
}
