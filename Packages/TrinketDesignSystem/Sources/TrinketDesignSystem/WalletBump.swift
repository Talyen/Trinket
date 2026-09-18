import SwiftUI

private enum WalletBumpPhase: CaseIterable {
    case resting
    case increased
    case settled
}

extension View {
    func trinketWalletIncreaseBump(trigger: Int, delay: TimeInterval = 0) -> some View {
        modifier(WalletBumpModifier(trigger: trigger, delay: delay))
    }
}

private struct WalletBumpModifier: ViewModifier {
    let trigger: Int
    let delay: TimeInterval

    @Environment(\.isDecorativeMotionActive) private var isMotionActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // Match the shine/plasma parking contract: no bump for Reduce Motion
        // users or behind presentations; the amount text still updates.
        if reduceMotion || !isMotionActive || scenePhase != .active {
            content
        } else {
            content.phaseAnimator(WalletBumpPhase.allCases, trigger: trigger) { content, phase in
                content.scaleEffect(phase == .increased ? TrinketMotion.Interaction.walletIncreaseScale : 1)
            } animation: { phase in
                switch phase {
                case .resting: nil
                case .increased: TrinketMotion.Interaction.walletBump.delay(max(0, delay))
                case .settled: TrinketMotion.Interaction.press
                }
            }
        }
    }
}
