import Foundation
import os
import SwiftUI
import TrinketFeatureContracts

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
        modifier(FramePacingIntervalModifier(signposter: AppFramePacingSignposts.signposter, name: name, isActive: isActive))
    }
}

private struct FramePacingIntervalModifier: ViewModifier {
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
