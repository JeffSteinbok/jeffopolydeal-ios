import OSLog
import SwiftUI
import WebKit

/// Why a load stopped, in terms the shell can put in front of a player.
enum GameWebLoadFailure: Equatable {
    case offline
    case unreachable(String)

    /// Returns nil for the cancellation WebKit reports when we deliberately stop
    /// a navigation ourselves, which is not a failure the player should see.
    init?(_ error: Error) {
        let error = error as NSError

        let isOurOwnCancellation = (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == "WebKitErrorDomain" && error.code == 102)
        if isOurOwnCancellation { return nil }

        let offlineCodes = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorDataNotAllowed,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorNetworkConnectionLost,
        ]
        if error.domain == NSURLErrorDomain, offlineCodes.contains(error.code) {
            self = .offline
        } else {
            self = .unreachable(error.localizedDescription)
        }
    }

    var title: String {
        switch self {
        case .offline: "You're Offline"
        case .unreachable: "Can't Reach the Game"
        }
    }

    var message: String {
        switch self {
        case .offline:
            "Jeffopoly Deal needs an internet connection to play. Check your connection and try again."
        case .unreachable(let detail):
            detail
        }
    }
}

/// Hosts the shared React gameplay client.
///
/// Navigation is pinned to the gameplay surface: the client leaving it is how it
/// hands control back to the shell, and any other link opens in the system
/// browser instead of silently replacing the game.
struct GameWebView: UIViewRepresentable {
    let entryURL: URL
    /// Changing this re-loads the entry URL; the retry button bumps it.
    let reloadToken: Int
    /// Games found on the local network, pushed into the client's start page.
    let nearbyGames: [NearbyGamesService.NearbyGame]
    /// APNs token, which only the shell can hold. The client registers it.
    let pushToken: String?
    /// Why push is or is not working on this device, reported onward for support.
    let pushDiagnostics: String
    /// Bumped when the app returns to the foreground, so the client can check a
    /// connection that iOS may have frozen or killed while suspended.
    let foregroundToken: Int
    /// A game a notification tap asked for, if any.
    let requestedGameCode: String?
    let onLoadingChanged: (Bool) -> Void
    let onFailure: (GameWebLoadFailure) -> Void
    let onGameContext: (GameBridge.GameContext) -> Void
    /// Called once a requested game has been handed to the client.
    let onRequestedGameHandled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // A persistent data store keeps the client's own localStorage across
        // launches, matching how the same code behaves in a browser.
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(
            context.coordinator.bridge,
            name: GameBridge.handlerName
        )

        let webView = KeyboardAccessoryFreeWebView(frame: .zero, configuration: configuration)
        // Distinguishes app traffic from browser and PWA traffic in server-side
        // telemetry, which otherwise cannot tell them apart now that both reach
        // the hub through the same JavaScript client.
        webView.configuration.applicationNameForUserAgent = GameWebURL.userAgentSuffix
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.loadIfNeeded(entryURL, token: reloadToken, in: webView)
        context.coordinator.pushInboundState(in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: GameBridge.handlerName
        )
        webView.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: GameWebView

        /// Owned here so it lives exactly as long as the web view it serves.
        let bridge: GameBridge
        private let haptics = HapticEngine()

        private var loaded: (url: URL, token: Int)?
        private var isPageLoaded = false
        private var pushedNearbyGames: String?
        private var pushedPushToken: String?
        private var pushedDiagnostics: String?
        private var pushedForegroundToken: Int?
        private var pushedGameCode: String?

        init(_ parent: GameWebView) {
            self.parent = parent
            self.bridge = GameBridge(haptics: haptics)
            super.init()
            haptics.prepare()
            bridge.onGameContext = { [weak self] context in
                self?.parent.onGameContext(context)
            }
        }

        // MARK: - Loading

        /// `url` is where gameplay *starts*, not a binding. Once loaded, the web
        /// client owns navigation — re-loading because the shell learned the
        /// resolved game code would drop the player out of the game they just
        /// created. Only an explicit retry (a new token) reloads.
        func loadIfNeeded(_ url: URL, token: Int, in webView: WKWebView) {
            guard let loaded else {
                startLoad(url, token: token, in: webView)
                return
            }
            guard loaded.token != token else { return }
            startLoad(url, token: token, in: webView)
        }

        private static let log = Logger(subsystem: "net.steinbok.jeffopolydeal", category: "webview")

        private func startLoad(_ url: URL, token: Int, in webView: WKWebView) {
            Self.log.debug("loading \(url.absoluteString, privacy: .public)")
            loaded = (url, token)
            isPageLoaded = false
            resetPushedState()
            parent.onLoadingChanged(true)
            webView.load(URLRequest(url: url))
        }

        /// A fresh page knows none of what we told the last one.
        private func resetPushedState() {
            pushedNearbyGames = nil
            pushedPushToken = nil
            pushedDiagnostics = nil
            pushedForegroundToken = nil
            pushedGameCode = nil
        }

        // MARK: - Inbound state

        /// Hands the client everything only the shell can know. Each value is
        /// sent once per change, so a re-render never replays a notification tap
        /// or re-registers a token that has not moved.
        func pushInboundState(in webView: WKWebView) {
            guard isPageLoaded else { return }

            if let json = encode(parent.nearbyGames), json != pushedNearbyGames {
                pushedNearbyGames = json
                call("setNearbyGames(\(json))", in: webView)
            }

            if let token = parent.pushToken, token != pushedPushToken {
                pushedPushToken = token
                Self.log.info("handing APNs token to the client, length \(token.count, privacy: .public)")
                call("setPushToken(\(quoted(token)))", in: webView)
            }

            if parent.pushDiagnostics != pushedDiagnostics {
                pushedDiagnostics = parent.pushDiagnostics
                call("setPushDiagnostics(\(quoted(parent.pushDiagnostics)))", in: webView)
            }

            if parent.foregroundToken != pushedForegroundToken {
                let isFirst = pushedForegroundToken == nil
                pushedForegroundToken = parent.foregroundToken
                // The first value is just the launch state, not a return.
                if !isFirst { call("setLifecycle(\"active\")", in: webView) }
            }

            if let code = parent.requestedGameCode, code != pushedGameCode {
                pushedGameCode = code
                call("openGame(\(quoted(code)))", in: webView)
                parent.onRequestedGameHandled()
            }
        }

        private func encode(_ games: [NearbyGamesService.NearbyGame]) -> String? {
            let payload = games.map { ["gameCode": $0.gameCode, "hostName": $0.hostName] }
            guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        /// JSON-encodes a string so a stray quote cannot break out of the call.
        private func quoted(_ value: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let json = String(data: data, encoding: .utf8)
            else { return "\"\"" }
            return String(json.dropFirst().dropLast())
        }

        private func call(_ expression: String, in webView: WKWebView) {
            webView.evaluateJavaScript("window.jeffopolyNative?.\(expression)")
        }

        // MARK: - Navigation policy

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Sub-frames are the client's own business; only police the main frame
            // and new-window navigations (where targetFrame is nil).
            if let targetFrame = navigationAction.targetFrame, !targetFrame.isMainFrame {
                decisionHandler(.allow)
                return
            }

            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // The client owns everything on our origin now, start page included.
            guard GameWebURL.isSameOrigin(url) else {
                decisionHandler(.cancel)
                openExternally(url)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // target="_blank" has no window to open into; send it to Safari.
            if let url = navigationAction.request.url {
                openExternally(url)
            }
            return nil
        }

        private func openExternally(_ url: URL) {
            guard let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else { return }
            UIApplication.shared.open(url)
        }

        // MARK: - Load lifecycle

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onLoadingChanged(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            parent.onLoadingChanged(false)
            resetPushedState()
            pushInboundState(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // The renderer was jettisoned, usually under memory pressure. Reload
            // rather than leaving the player staring at a blank game.
            guard let url = loaded?.url else { return }
            isPageLoaded = false
            parent.onLoadingChanged(true)
            webView.load(URLRequest(url: url))
        }

        private func report(_ error: Error) {
            parent.onLoadingChanged(false)
            guard let failure = GameWebLoadFailure(error) else { return }
            parent.onFailure(failure)
        }
    }
}
