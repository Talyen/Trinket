import Foundation
import os
import SwiftUI

/// Signposts intentionally ship in release-like builds so Instruments can profile the
/// same Battle effect pipeline players run. With no signpost consumer, the system log
/// path remains lightweight.
enum BattleFramePacingSignposts {
    static let subsystem = "com.trinket.framepacing"
    static let category = "BattleEffects"
    static let signposter = OSSignposter(subsystem: subsystem, category: category)
    private static let eventLog = OSLog(subsystem: subsystem, category: category)

    enum Name {
        static let cardCast: StaticString = "CardCast"
        static let keywordBurst: StaticString = "KeywordBurst"
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
        os_signpost(
            .event,
            log: eventLog,
            name: name,
            "%{public}@",
            detail as NSString
        )
    }
}

private struct FramePacingSignpostModifier: ViewModifier {
    let name: StaticString
    let isActive: Bool

    @State private var intervalState: OSSignpostIntervalState?

    func body(content: Content) -> some View {
        content
            .onChange(of: isActive, initial: true) { _, active in
                if active {
                    beginIfNeeded()
                } else {
                    endIfNeeded()
                }
            }
            .onDisappear {
                endIfNeeded()
            }
    }

    private func beginIfNeeded() {
        guard intervalState == nil else { return }
        intervalState = BattleFramePacingSignposts.signposter.beginInterval(name)
    }

    private func endIfNeeded() {
        guard let intervalState else { return }
        BattleFramePacingSignposts.signposter.endInterval(name, intervalState)
        self.intervalState = nil
    }
}

extension View {
    func battleFramePacingSignpost(_ name: StaticString, isActive: Bool) -> some View {
        modifier(FramePacingSignpostModifier(name: name, isActive: isActive))
    }
}
