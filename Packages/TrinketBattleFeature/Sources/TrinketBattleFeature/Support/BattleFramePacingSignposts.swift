import Foundation
import os
import SwiftUI
import TrinketFeatureContracts

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
        modifier(BattleFramePacingIntervalModifier(signposter: BattleFramePacingSignposts.signposter, name: name, isActive: isActive))
    }
}

private struct BattleFramePacingIntervalModifier: ViewModifier {
    let signposter: OSSignposter
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
        intervalState = signposter.beginInterval(name)
    }

    private func endIfNeeded() {
        guard let intervalState else { return }
        signposter.endInterval(name, intervalState)
        self.intervalState = nil
    }
}
