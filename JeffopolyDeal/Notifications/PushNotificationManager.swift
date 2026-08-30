import OSLog
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushNotificationManager.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationManager.shared.didFailToRegister(error: error)
    }
}

/// Owns the APNs relationship: permission, the device token, and what happens
/// when a notification is tapped.
///
/// The shell holds the token but never registers it itself — the web client owns
/// the hub connection, so the token is handed inward across the bridge and
/// registered from there.
@MainActor
final class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()

    private static let log = Logger(subsystem: "net.steinbok.jeffopolydeal", category: "push")

    @Published private(set) var deviceToken: String?

    /// Why push is or is not working, in a form that can be reported to the
    /// server. Without it, "no token" on the server is indistinguishable from
    /// a dozen different device-side causes.
    @Published private(set) var diagnostics: String = "starting"

    /// Set when a notification tap asks for a particular game. The host view
    /// clears it once the client has been told, so a second tap still routes.
    @Published var requestedGameCode: String?

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Task { await requestAuthorization() }
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = hex
        diagnostics = "token-received-length-\(hex.count)"
        // Length only — the token itself is not something to put in a log.
        Self.log.info("APNs token received, length \(hex.count, privacy: .public)")
    }

    func didFailToRegister(error: Error? = nil) {
        deviceToken = nil
        let reason = (error as NSError?).map { "\($0.domain)-\($0.code)" } ?? "unknown"
        diagnostics = "registration-failed-\(reason)"
        Self.log.error("APNs registration failed: \(reason, privacy: .public)")
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Nothing at all with the app open: the client already shows whose turn
        // it is, so a banner and a sound are both just noise over the game.
        []
    }

    /// A tap on a turn notification. The engine puts the game code in the payload
    /// so we can route straight back into that game rather than the start page.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let code = (userInfo["gameCode"] as? String)?.uppercased(), !code.isEmpty else { return }
        await MainActor.run { self.requestedGameCode = code }
    }

    private func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional

        if settings.authorizationStatus == .notDetermined {
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) == true
        }

        Self.log.info("notification authorization status \(settings.authorizationStatus.rawValue, privacy: .public), authorized \(isAuthorized, privacy: .public)")

        if isAuthorized {
            diagnostics = "authorized-awaiting-token"
            Self.log.info("registering for remote notifications")
            UIApplication.shared.registerForRemoteNotifications()
        } else {
            diagnostics = "not-authorized-status-\(settings.authorizationStatus.rawValue)"
            Self.log.error("not authorized for notifications; no APNs token will be requested")
        }
    }
}
