import UIKit

/// Best-effort "what does this phone think your name is". There's no public
/// iOS API to read the Contacts "Me" card — unifiedMeContactWithKeys(toFetch:)
/// is macOS-only and throws "unavailable in iOS" at compile time. Instead,
/// this derives a name from UIDevice.current.name, which iOS sets from the
/// owner's name during setup (e.g. "Jeff's iPhone") — no permission prompt
/// needed. Silently returns nil if the device name doesn't follow that
/// possessive pattern (e.g. it was renamed to something generic).
enum DeviceName {
    static func guessMyName() -> String? {
        let deviceName = UIDevice.current.name
        guard let range = deviceName.range(of: "’s ") ?? deviceName.range(of: "'s ") else {
            return nil
        }
        let name = String(deviceName[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
