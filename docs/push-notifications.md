# Turn notifications: how they work, and how to debug them

No Firebase. The game server is the push provider: it signs an ES256 JWT with
an APNs key and posts directly to `api.push.apple.com` over HTTP/2.

## The chain

```
iOS grants permission
  → shell receives an APNs device token
  → shell hands it to the client over the bridge  (setPushToken)
  → client registers it on the hub               (RegisterPushToken)
  → server stores it per player, not per connection
  → on a turn start, server signs a JWT and posts to Apple
```

Every one of those steps has failed at least once. Work from the server
backwards, because the server tells you the most for the least effort.

## Where to look

Application Insights (`jeffopolydeal-appinsights`) has all of it:

```bash
az monitor app-insights query --app jeffopolydeal-appinsights -g jeffopolydeal \
  --analytics-query "traces | where timestamp > ago(30m) \
    | where message has_any ('Push status','RegisterPushToken','APNs') \
    | project timestamp, message | order by timestamp desc" -o json
```

| What you see | What it means |
| --- | --- |
| `Push status ... hasToken=False native=none` | The shell never delivered anything. Suspect the bridge, not push. |
| `Push status ... hasToken=False native=registration-failed-...` | APNs refused the device. Provisioning or entitlement. |
| `Push status ... hasToken=False native=not-authorized-...` | Notifications are off for the app in Settings. |
| `Push status ... hasToken=True` but no `RegisterPushToken` | The client has it and is not sending it. |
| `RegisterPushToken rejected: malformed token` | Token failed the hex/length check. |
| `RegisterPushToken rejected: connection is not player` | Registered outside a game; only works once joined. |
| `no device tokens registered for player` | Nothing to send to. Look upstream. |
| `Sending APNs turn notification to N device(s)` | The server sent it. The problem is Apple-side or on the device. |

## Check the credentials without a device

This proves the key, team, key id and topic in seconds:

```bash
JWT=$(python3 -c "
import jwt, time
key = open('AuthKey_XXXXXXXXXX.p8').read()
print(jwt.encode({'iss':'Y7KVX7666P','iat':int(time.time())}, key,
      algorithm='ES256', headers={'alg':'ES256','kid':'XXXXXXXXXX'}))")

curl -s --http2 -o /dev/null -w "%{http_code}\n" \
  -H "apns-topic: net.steinbok.jeffopolydeal" -H "apns-push-type: alert" \
  -H "authorization: bearer $JWT" -d '{"aps":{"alert":{"title":"t","body":"t"}}}' \
  "https://api.push.apple.com/3/device/$(printf '0%.0s' {1..64})"
```

`400 BadDeviceToken` means the credentials are **good** — Apple accepted
everything and rejected only the fake token. `403` means the key is wrong.

## The bug that cost two days

The shell delivered inbound values with `window.jeffopolyNative?.setPushToken(...)`.
The client installs that object from a deferred module script, so it does not
exist when `didFinish` fires. Optional chaining made the call a silent no-op, and
the value was recorded as delivered, so it was never retried. The devices were
obtaining tokens correctly; the bridge discarded them.

Nearby discovery hid it, because that list keeps changing and a later push
lands. One-shot pushes are the ones that vanish.

**If an inbound value never arrives, probe the bridge before theorising about
the payload:**

```swift
webView.evaluateJavaScript("typeof window.jeffopolyNative") { value, _ in
    print("jeffopolyNative is", String(describing: value))
}
```

## Configuration

Server (Azure app settings on `jeffopolydeal`):

| Setting | Notes |
| --- | --- |
| `APNS__TEAM_ID` | `Y7KVX7666P` |
| `APNS__KEY_ID` | From the APNs key in Apple Developer → Keys |
| `APNS__PRIVATE_KEY` | The `.p8`, newlines as `\n`. Cannot be re-downloaded — keep a backup. |
| `APNS__USE_SANDBOX` | Leave unset. Release builds are `aps-environment: production`. |

The key is **Team Scoped (All Topics)**, **Sandbox & Production** — both locked
by Apple at creation — so it serves Jeffpardy and SteinbokHome too.

## Known limitation

`PushTokenStore` is in memory. Every app-service restart drops all tokens until
each player rejoins a game. Expect "notifications stopped after a deploy"; it is
not a bug. Move to Redis or a table if it becomes annoying.
