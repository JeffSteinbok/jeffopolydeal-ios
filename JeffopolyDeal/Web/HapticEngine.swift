import CoreHaptics
import UIKit

/// The semantic haptic vocabulary, mirroring `HapticEvent` in
/// src/web/utilities/Haptics.ts. These name moments in the game; what each one
/// feels like is decided here, not by the web client.
enum HapticEvent: String, CaseIterable {
    case selection
    case cardPlayed
    case paymentSettled
    case bigHit
    case invalidMove
    case turnStarted
    case gameWon
}

@MainActor
protocol HapticPerforming: AnyObject {
    func perform(_ event: HapticEvent)
}

/// Maps semantic game events onto system feedback.
///
/// Everything but a win uses the standard generators, which stay consistent
/// with the rest of iOS. A win is the one moment worth a bespoke pattern, and
/// it degrades to a plain success notification on hardware without Core Haptics.
@MainActor
final class HapticEngine: HapticPerforming {
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    private var impacts: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private var celebrationEngine: CHHapticEngine?

    func perform(_ event: HapticEvent) {
        switch event {
        case .selection:
            selection.selectionChanged()
        case .cardPlayed:
            impact(.light)
        case .paymentSettled:
            impact(.medium)
        case .bigHit:
            impact(.heavy)
        case .invalidMove:
            notification.notificationOccurred(.error)
        case .turnStarted:
            notification.notificationOccurred(.success)
        case .gameWon:
            playCelebration()
        }
    }

    /// Warms the generators so the first feedback of a game is not late.
    func prepare() {
        selection.prepare()
        notification.prepare()
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = impacts[style] ?? {
            let new = UIImpactFeedbackGenerator(style: style)
            impacts[style] = new
            return new
        }()
        generator.impactOccurred()
    }

    private func playCelebration() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            notification.notificationOccurred(.success)
            return
        }

        do {
            let engine = try celebrationEngine ?? CHHapticEngine()
            celebrationEngine = engine
            try engine.start()

            // Three rising taps into a short swell.
            var events: [CHHapticEvent] = (0..<3).map { index in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.6 + Float(index) * 0.2),
                        .init(parameterID: .hapticSharpness, value: 0.4 + Float(index) * 0.2),
                    ],
                    relativeTime: Double(index) * 0.12
                )
            }
            events.append(
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.7),
                        .init(parameterID: .hapticSharpness, value: 0.3),
                    ],
                    relativeTime: 0.38,
                    duration: 0.35
                )
            )

            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Never let a celebration failure surface to the player.
            notification.notificationOccurred(.success)
        }
    }
}
