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
    let onLoadingChanged: (Bool) -> Void
    let onFailure: (GameWebLoadFailure) -> Void
    let onGameCodeResolved: (String) -> Void
    let onExit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // A persistent data store keeps the client's own localStorage across
        // launches, matching how the same code behaves in a browser.
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.startObserving(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.loadIfNeeded(entryURL, token: reloadToken, in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObserving()
        webView.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: GameWebView

        private var urlObservation: NSKeyValueObservation?
        private var loaded: (url: URL, token: Int)?
        private var reportedGameCode: String?

        init(_ parent: GameWebView) {
            self.parent = parent
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

        private func startLoad(_ url: URL, token: Int, in webView: WKWebView) {
            loaded = (url, token)
            reportedGameCode = GameWebURL.gameCode(in: url)
            parent.onLoadingChanged(true)
            webView.load(URLRequest(url: url))
        }

        /// The client rewrites its own URL once the server assigns a game code,
        /// via `history.replaceState`. That fires no navigation callback, so KVO
        /// on `url` is what surfaces it.
        func startObserving(_ webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, change in
                guard let url = change.newValue.flatMap({ $0 }) else { return }
                Task { @MainActor in self?.handleURLChange(url) }
            }
        }

        func stopObserving() {
            urlObservation?.invalidate()
            urlObservation = nil
        }

        private func handleURLChange(_ url: URL) {
            guard let code = GameWebURL.gameCode(in: url), code != reportedGameCode else { return }
            reportedGameCode = code
            parent.onGameCodeResolved(code)
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

            if GameWebURL.isGameplay(url) {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)

            if GameWebURL.isShellRoot(url) {
                parent.onExit()
            } else {
                openExternally(url)
            }
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
            parent.onLoadingChanged(false)
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
