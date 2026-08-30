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
        PushNotificationManager.shared.didFailToRegister()
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

    @Published private(set) var deviceToken: String?

    /// Set when a notification tap asks for a particular game. The host view
    /// clears it once the client has been told, so a second tap still routes.
    @Published var requestedGameCode: String?

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Task { await requestAuthorization() }
    }

    func didRegister(deviceToken: Data) {
        self.deviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    func didFailToRegister() {
        deviceToken = nil
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // The client already shows whose turn it is, so retain the sound without
        // stacking a system banner on top of the in-game UI.
        [.sound]
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

        if isAuthorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
