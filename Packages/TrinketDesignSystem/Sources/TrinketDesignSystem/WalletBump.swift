import SwiftUI

private enum WalletBumpPhase: CaseIterable {
    case resting
    case increased
    case settled
}

extension View {
    func trinketWalletIncreaseBump(trigger: Int, delay: TimeInterval = 0) -> some View {
        phaseAnimator(WalletBumpPhase.allCases, trigger: trigger) { content, phase in
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
