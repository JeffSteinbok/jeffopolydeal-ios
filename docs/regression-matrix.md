# Migration regression matrix

Gameplay moved from a duplicate SwiftUI implementation to the shared React
client running in a `WKWebView` (see [#10](https://github.com/JeffSteinbok/jeffopolydeal-ios/issues/10)).
This is the checklist that says whether that migration actually held.

Run the **On device** column before any release that changes the shell, the
bridge, or the entry contract. The automated column runs in CI on every push.

## How to run it

```bash
# Swift: bridge decoding, routing, deduplication, URL building and classification
xcodebuild test -project JeffopolyDeal.xcodeproj -scheme JeffopolyDeal \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"

# Web: host detection, inbound bridge, haptic derivation
cd ../jeffopolydeal && npm test
```

Against a local backend, point `JEFFOPOLYDEAL_BASE_URL` at the Vite dev server
(`http://localhost:5173`) and run both `dotnet run` and `npm run dev`.

## Entry

| # | Scenario | Expected | Automated | On device |
| --- | --- | --- | --- | --- |
| 1 | Cold launch, no saved session | Web start page, device name prefilled | — | ☐ |
| 2 | Create game | Lobby with a game code, no code re-entry | — | ☐ |
| 3 | Join by code | Joins the named game | — | ☐ |
| 4 | Nearby discovery | Host's lobby appears under Nearby Games on another device | — | ☐ |
| 5 | Tap a nearby game | Code fills in, join succeeds | — | ☐ |
| 6 | Share invite link | Link opens the app, not Safari, and enters the game | — | ☐ |
| 7 | Cold launch with saved session | Rejoins the game in progress | — | ☐ |

## Gameplay

Gameplay itself is the shared client's responsibility and is covered by that
repository's tests. What matters here is that it behaves identically *embedded*.

| # | Scenario | Expected | Automated | On device |
| --- | --- | --- | --- | --- |
| 8 | Lobby: add bot, start game | Both work from the embedded client | — | ☐ |
| 9 | Draw, play, end turn | Same as browser | — | ☐ |
| 10 | Money and property cards | Same as browser | — | ☐ |
| 11 | Wildcards and property movement | Same as browser | — | ☐ |
| 12 | Action cards and responses | Same as browser | — | ☐ |
| 13 | Payment selection | Same as browser | — | ☐ |
| 14 | Discard flow | Same as browser | — | ☐ |
| 15 | Game over and results | Same as browser | — | ☐ |
| 16 | Leave game | Returns to the start page, no stranded SignalR session | — | ☐ |

## Shell capabilities

| # | Scenario | Expected | Automated | On device |
| --- | --- | --- | --- | --- |
| 17 | Bridge rejects malformed messages | Dropped, never dispatched | `GameBridgeTests` | — |
| 18 | One game event, one haptic | Deduplicated on both sides | `GameBridgeTests`, `NativeBridge.test.ts` | — |
| 19 | Haptics feel right | Each of the seven events is distinguishable | — | ☐ |
| 20 | Turn notification arrives | Banner while backgrounded | — | ☐ |
| 21 | Notification tap | Opens the app into that game | `NativeInbound.test.ts` | ☐ |
| 22 | External link | Opens in Safari, does not replace the game | `GameWebURLTests` | ☐ |

## Resilience

| # | Scenario | Expected | Automated | On device |
| --- | --- | --- | --- | --- |
| 23 | Background and return | Gameplay resumes; connection recovered if it died | `NativeInbound.test.ts` | ☐ |
| 24 | Airplane mode on, then off | Reconnects and resyncs without a restart | — | ☐ |
| 25 | Server unreachable at launch | Native error screen with a working Try Again | — | ☐ |
| 26 | Expired or invalid game code | Clear recovery back to the start page | — | ☐ |
| 27 | Renderer terminated under memory pressure | Reloads rather than showing a blank game | — | ☐ |

## Layout

| # | Scenario | Expected | Automated | On device |
| --- | --- | --- | --- | --- |
| 28 | iPhone portrait | No clipping, safe areas respected | — | ☐ |
| 29 | iPhone landscape | Usable, no clipping | — | ☐ |
| 30 | iPad, both orientations | Appropriately sized, not a stretched phone layout | — | ☐ |
| 31 | Rotation mid-game | Relayout without losing state | — | ☐ |
| 32 | Long-press on a card | Inspects; no text selection or share sheet | — | ☐ |
| 33 | VoiceOver pass | Cards and actions are reachable and labelled | — | ☐ |

## The other clients still work

The point of this migration was one implementation, so a regression here is a
regression everywhere.

| # | Scenario | Expected | Automated | On device |
| --- | --- | --- | --- | --- |
| 34 | Browser | Start page and gameplay unchanged | `npm test` | ☐ |
| 35 | Installed PWA | Unchanged, still reports as `pwa` in telemetry | `NativeHost.test.ts` | ☐ |
| 36 | Telemetry | App, PWA, and browser distinguishable in App Insights | — | ☐ |

## Multiplayer scenarios needing real devices

These cannot be simulated meaningfully and need two or more people:

- A full game to completion with at least one other human player.
- One player backgrounding the app mid-game while others continue.
- One player losing network entirely and rejoining.
- Nearby discovery between two physical devices on the same Wi-Fi, and over
  Bluetooth with Wi-Fi disabled.
- Turn notifications arriving on a locked device.

## Before removing anything else

The duplicate SwiftUI gameplay implementation was removed in
[#21](https://github.com/JeffSteinbok/jeffopolydeal-ios/pull/21) once rows 1-5,
8-9 and 17-18 were confirmed. Anything removed in future should clear the rows
that cover it first.
