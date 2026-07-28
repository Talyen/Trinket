import Foundation
import os
import SwiftUI
import TrinketBattleFeature
import TrinketFeatureSupport

/// Navigation and shell destination signposts for Instruments Animation Hitches /
/// Time Profiler. Shares the frame-pacing subsystem with battle effect signposts so
/// one Instruments filter covers both.
public enum AppFramePacingSignposts {
    public static let subsystem = BattleFramePacingSignposts.subsystem
    public static let category = "AppNavigation"
    public static let signposter = OSSignposter(subsystem: subsystem, category: category)
    private static let eventLog = OSLog(subsystem: subsystem, category: category)

    public enum Name {
        public static let tabSwitch: StaticString = "TabSwitch"
        public static let sheetPresent: StaticString = "SheetPresent"
        public static let navigationPush: StaticString = "NavigationPush"
        public static let stageSelectBattleActivate: StaticString = "StageSelectBattleActivate"
    }

    public static func event(_ name: StaticString, detail: String) {
        os_signpost(
            .event,
            log: eventLog,
            name: name,
            "%{public}@",
            detail as NSString
        )
    }
}

private struct AppFramePacingSignpostModifier: ViewModifier {
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
        intervalState = AppFramePacingSignposts.signposter.beginInterval(name)
    }

    private func endIfNeeded() {
        guard let intervalState else { return }
        AppFramePacingSignposts.signposter.endInterval(name, intervalState)
        self.intervalState = nil
    }
}

public extension View {
    func appFramePacingSignpost(_ name: StaticString, isActive: Bool) -> some View {
        modifier(AppFramePacingSignpostModifier(name: name, isActive: isActive))
    }
}
