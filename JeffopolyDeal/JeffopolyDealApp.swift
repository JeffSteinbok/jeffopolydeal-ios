import SwiftUI

@main
struct JeffopolyDealApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
