import Foundation
import os
import SwiftUI
import TrinketFeatureContracts

/// Navigation and shell destination signposts for Instruments Animation Hitches /
/// Time Profiler. Shares the frame-pacing subsystem with battle effect signposts so
/// one Instruments filter covers both.
public enum AppFramePacingSignposts {
    public static let subsystem = FramePacingSignpostSupport.subsystem
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
        FramePacingSignpostSupport.event(log: eventLog, name: name, detail: detail)
    }
}

public extension View {
    func appFramePacingSignpost(_ name: StaticString, isActive: Bool) -> some View {
        framePacingInterval(signposter: AppFramePacingSignposts.signposter, name: name, isActive: isActive)
    }
}
