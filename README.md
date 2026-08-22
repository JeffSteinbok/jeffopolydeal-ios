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

Release builds connect to `https://jeffopolydeal.azurewebsites.net`. Debug builds connect to the backend at `http://localhost:5010`.

Start the backend from the [main Jeffopoly Deal repository](https://github.com/JeffSteinbok/jeffopolydeal):

```bash
dotnet run --project src/JeffopolyDeal.Game/JeffopolyDeal.Game.csproj
```

## Architecture

- **SwiftUI** provides the native application and game interface.
- **SignalR-Client-Swift** connects directly to the existing game hub.
- **Multipeer Connectivity** advertises public game codes for nearby discovery.
- Codable client models mirror the backend's public game-state contract.

The backend, browser client, shared game engine, and bot AI remain in the [Jeffopoly Deal repository](https://github.com/JeffSteinbok/jeffopolydeal).

## TestFlight automation

`Publish TestFlight` can be started manually from the repository's **Actions** tab.

Configure these repository values under **Settings -> Secrets and variables -> Actions**:

| Type | Name | Value |
| --- | --- | --- |
| Variable | `APPSTORE_ISSUER_ID` | App Store Connect API issuer ID |
| Variable | `APPSTORE_API_KEY_ID` | App Store Connect API key ID |
| Secret | `APPSTORE_API_PRIVATE_KEY` | Full contents of the `.p8` API private key |
| Secret | `APPSTORE_CERTIFICATES_FILE_BASE64` | Base64-encoded Apple Distribution `.p12` |
| Secret | `APPSTORE_CERTIFICATES_PASSWORD` | Password for the `.p12` |

The API key requires App Manager access. The provisioning profile must be named `AppStore net.steinbok.jeffopolydeal`.

