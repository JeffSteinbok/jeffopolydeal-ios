# Jeffopoly Deal for iOS

A native SwiftUI client for [Jeffopoly Deal](https://github.com/JeffSteinbok/jeffopolydeal).

The app connects directly to the Jeffopoly Deal SignalR game hub and supports the complete player experience: creating and joining games, nearby-game discovery, managing a hand and property board, playing cards, responding to actions, paying opponents, and viewing game results.

## Requirements

- Xcode 16 or later
- XcodeGen
- iOS 17 or later

## Getting started

```bash
brew install xcodegen
xcodegen generate
open JeffopolyDeal.xcodeproj
```

The project is configured for automatic signing with the app's Apple development team. Select another team in Xcode if needed before running on a physical device.

## Turn notifications

The app requests notification permission on launch, registers its APNs token after joining or rejoining a game, and displays an in-app banner with sound and haptic feedback when its turn begins. Background and locked-device alerts require:

- Push Notifications enabled for `net.steinbok.jeffopolydeal` in Apple Developer.
- A provisioning profile containing the push entitlement.
- The backend APNs settings documented in the main repository.
- A physical device for end-to-end APNs testing. The simulator supports the foreground experience and simulated push payloads, but not production token delivery.

## Server configuration

The app connects to `https://jeffopolydeal.azurewebsites.net` by default. To use a local or alternate server, change `JEFFOPOLYDEAL_BASE_URL` in `project.yml`, then regenerate the Xcode project. A physical device cannot reach a server through `localhost`; use your Mac's LAN address or a trusted HTTPS development endpoint.

Start the backend from the [main Jeffopoly Deal repository](https://github.com/JeffSteinbok/jeffopolydeal):

```bash
dotnet run --project src/JeffopolyDeal.Game/JeffopolyDeal.Game.csproj
```

## Architecture

Gameplay is owned by the shared React client, not reimplemented natively. The
app is a SwiftUI shell that owns app entry and platform capabilities and hands
gameplay off to that client in a `WKWebView`.

```text
ASP.NET game engine
      │
   SignalR
      │
React gameplay client
   ┌──┴─────────────┐
Browser          WKWebView
                    │
               SwiftUI shell
       nearby / sharing / deep links
       haptics / push / lifecycle
```

There is one implementation of the game, and it is not here. The React client
owns the whole player experience — start page, lobby, gameplay, and the SignalR
connection. This app is the shell around it.

**Swift owns** what the web cannot do for itself:

- **`GameWebHostView`** — the window, and the loading, offline, error, and retry
  chrome around the client.
- **Multipeer Connectivity** — discovering games on the local network. The client
  reports which game it is in, the shell advertises or browses accordingly, and
  discovered games are pushed back into the client's start page.
- **Push notifications** — permission, the APNs token, and notification taps. The
  token is handed to the client, which registers it over its own hub connection.
- **Session memory** — only enough to route a notification tap back to a game.

**Swift does not own** gameplay rendering, gameplay state, mirrored DTOs, or a
second SignalR connection. The backend, browser client, shared game engine, and
bot AI all remain in the
[Jeffopoly Deal repository](https://github.com/JeffSteinbok/jeffopolydeal).

### Entry contract

The shell opens the client at the site root with the device name as a hint for
the name field. It can also enter one game directly at `{base}/play` — used by a
shared link or a notification tap. `JeffopolyDeal/Web/GameWebURL.swift` builds
these and `src/web/utilities/NativeHost.ts` in the main repository parses them;
the two must stay in sync.

| Parameter | Meaning |
| --- | --- |
| `v` | Contract version, currently `1`. A mismatch makes the client ignore the entry. |
| `host` | Which native shell is embedding, currently `ios`. |
| `pid` | Player id, owned by the shell's `SessionStore` rather than web `localStorage`. |
| `name` | Player display name. |
| `game` | Four-character game code to join. |
| `new` | `1` to ask the server for a new game instead of supplying `game`. |
| `rejoin` | `1` to attempt `RejoinGame` rather than `JoinGame`. |

### Bridge

Everything else crosses a small semantic bridge, documented in
`JeffopolyDeal/Web/GameBridge.swift` and `src/web/utilities/NativeBridge.ts`.

Outbound (client to shell) messages are `haptic` — one of seven semantic game
moments, mapped to feedback in `HapticEngine.swift` — and `gameContext`, which
reports the current game and phase so the shell knows whether to advertise a
lobby or browse for one.

Inbound (shell to client) calls arrive on `window.jeffopolyNative`:
`setNearbyGames`, `setPushToken`, `setLifecycle`, and `openGame`.

The client owns navigation within our own origin, including the start page. Any
link that leaves it opens in the system browser rather than replacing the game.

## TestFlight automation

`Publish TestFlight` can be started manually from the repository's **Actions** tab. `Ensure Fresh TestFlight Build` runs weekly and publishes through the same workflow when the newest App Store Connect build is at least 60 days old.

Configure these repository values under **Settings -> Secrets and variables -> Actions**:

| Type | Name | Value |
| --- | --- | --- |
| Variable | `APPSTORE_APP_ID` | Numeric App Store Connect app ID |
| Variable | `APPSTORE_ISSUER_ID` | App Store Connect API issuer ID |
| Variable | `APPSTORE_API_KEY_ID` | App Store Connect API key ID |
| Secret | `APPSTORE_API_PRIVATE_KEY` | Full contents of the `.p8` API private key |
| Secret | `APPSTORE_CERTIFICATES_FILE_BASE64` | Base64-encoded Apple Distribution `.p12` |
| Secret | `APPSTORE_CERTIFICATES_PASSWORD` | Password for the `.p12` |

The API key requires App Manager access. The provisioning profile must be named `AppStore net.steinbok.jeffopolydeal`.
