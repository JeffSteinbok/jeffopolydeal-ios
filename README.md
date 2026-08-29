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

- **SwiftUI** owns app entry, session identity, and the native capabilities
  below — not gameplay rendering or gameplay state.
- **`GameWebHostView`** presents the React client and owns the loading, error,
  offline, and retry chrome around it.
- **Multipeer Connectivity** advertises public game codes for nearby discovery.
- The backend, browser client, shared game engine, and bot AI remain in the
  [Jeffopoly Deal repository](https://github.com/JeffSteinbok/jeffopolydeal).

### Gameplay entry contract

The shell enters gameplay by loading `{base}/play` with the player's identity in
the query string. `JeffopolyDeal/Web/GameWebURL.swift` builds it and
`src/web/utilities/NativeHost.ts` in the main repository parses it; the two must
stay in sync.

| Parameter | Meaning |
| --- | --- |
| `v` | Contract version, currently `1`. A mismatch makes the client ignore the entry. |
| `host` | Which native shell is embedding, currently `ios`. |
| `pid` | Player id, owned by the shell's `SessionStore` rather than web `localStorage`. |
| `name` | Player display name. |
| `game` | Four-character game code to join. |
| `new` | `1` to ask the server for a new game instead of supplying `game`. |
| `rejoin` | `1` to attempt `RejoinGame` rather than `JoinGame`. |

Two conventions carry information back without a second gameplay state store in
Swift:

- After a create, the client rewrites its own URL with the code the server
  assigned. The shell observes the web view's URL and persists the session.
- To leave a game, the client navigates to the site root. The shell cancels that
  navigation and returns to `StartView`.

Navigation is otherwise pinned to `/play`: any other link opens in the system
browser rather than replacing the game.

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
