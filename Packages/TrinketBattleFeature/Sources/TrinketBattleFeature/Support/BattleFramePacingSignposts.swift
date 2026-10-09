import Foundation
import os
import SwiftUI
import TrinketFeatureContracts
import TrinketFeatureSupport

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
        static let playCardEngine: StaticString = "PlayCardEngine"
        static let playCardRejected: StaticString = "PlayCardRejected"
        static let turnTransition: StaticString = "TurnTransition"
        static let performanceScenario: StaticString = "PerformanceScenario"
    }

    static func event(_ name: StaticString, detail: String) {
        FramePacingSignpostSupport.event(log: eventLog, name: name, detail: detail)
    }
}

extension View {
    func battleFramePacingSignpost(_ name: StaticString, isActive: Bool) -> some View {
        modifier(FramePacingIntervalModifier(signposter: BattleFramePacingSignposts.signposter, name: name, isActive: isActive))
    }
}
