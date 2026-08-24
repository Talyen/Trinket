import Foundation
import os
import SwiftUI
import TrinketFeatureSupport

/// Signposts intentionally ship in release-like builds so Instruments can profile the
/// same Battle effect pipeline players run. With no signpost consumer, the system log
/// path remains lightweight.
public enum BattleFramePacingSignposts {
    public static let subsystem = FramePacingSignpostSupport.subsystem
    static let category = "BattleEffects"
    static let signposter = OSSignposter(subsystem: subsystem, category: category)
    private static let eventLog = OSLog(subsystem: subsystem, category: category)

    enum Name {
        static let cardCast: StaticString = "CardCast"
        static let chipPublish: StaticString = "ChipPublish"
        static let chipFlush: StaticString = "ChipFlush"
        static let chipHostApply: StaticString = "ChipHostApply"
        static let feedbackRasterBuild: StaticString = "FeedbackRasterBuild"
        static let ultimateCinematic: StaticString = "UltimateCinematic"
        static let playCardEngine: StaticString = "PlayCardEngine"
        static let playCardProjection: StaticString = "PlayCardProjection"
        static let playCardFeedback: StaticString = "PlayCardFeedback"
        static let playCardRejected: StaticString = "PlayCardRejected"
        static let turnTransition: StaticString = "TurnTransition"
        static let performanceScenario: StaticString = "PerformanceScenario"
    }

    static func event(_ name: StaticString, detail: String) {
        FramePacingSignpostSupport.event(log: eventLog, name: name, detail: detail)
    }
}

public enum FramePacingMeasurementControl {
    public static let reset = Notification.Name("Trinket.FramePacing.Reset")
}

extension View {
    func battleFramePacingSignpost(_ name: StaticString, isActive: Bool) -> some View {
        framePacingInterval(signposter: BattleFramePacingSignposts.signposter, name: name, isActive: isActive)
    }
}
