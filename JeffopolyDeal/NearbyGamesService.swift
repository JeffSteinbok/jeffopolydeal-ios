import MultipeerConnectivity
import UIKit

/// Lets nearby devices discover in-progress lobbies without typing a code.
/// This is discovery-only — no MCSession/peer connection is ever established;
/// the actual game still runs entirely over the existing SignalR hub once a
/// player taps a discovered game and it fills in the code. A host advertises
/// its game code while sitting in the Lobby phase; anyone on the Join screen
/// browses for those adverts over Bluetooth/local Wi-Fi.
@MainActor
final class NearbyGamesService: NSObject, ObservableObject {
    struct NearbyGame: Identifiable, Hashable {
        let id: MCPeerID
        let hostName: String
        let gameCode: String
    }

    @Published private(set) var nearbyGames: [NearbyGame] = []

    /// 1-15 chars, lowercase letters/numbers/hyphens only (MCNearbyServiceAdvertiser requirement).
    private static let serviceType = "jeffopolydl"

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

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
        nearbyGames = []
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
        guard let code = info?["code"] else { return }
        let host = info?["host"] ?? peerID.displayName
        Task { @MainActor in
            guard !self.nearbyGames.contains(where: { $0.id == peerID }) else { return }
            self.nearbyGames.append(NearbyGame(id: peerID, hostName: host, gameCode: code))
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.nearbyGames.removeAll { $0.id == peerID }
        }
    }
}
