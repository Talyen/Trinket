import Foundation
import Observation
import SwiftUI
import TrinketDesignSystem

/// Shared timing owner for victory / mystery reward reveal sequences.
@MainActor
@Observable
final class RewardRevealSequenceState {
    private(set) var visibleWalletRewardCount = 0
    private(set) var areItemsVisible = false
    private(set) var isSequenceComplete = false
    private var hasStarted = false
    private var revealTask: Task<Void, Never>?

    func start(itemCount: Int, walletCount: Int) {
        guard !hasStarted else { return }
        hasStarted = true
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            let clock = SuspendingClock()

            if itemCount > 0 || walletCount == 0 {
                try? await clock.sleep(for: .seconds(TrinketMotion.Reward.itemRevealDelay))
                guard !Task.isCancelled else { return }
                withAnimation(TrinketMotion.Reward.reveal) {
                    areItemsVisible = true
                }
            }

            if walletCount > 0 {
                for count in 1 ... walletCount {
                    try? await clock.sleep(for: .seconds(TrinketMotion.Reward.resourceStagger))
                    guard !Task.isCancelled else { return }
                    withAnimation(TrinketMotion.Reward.stateChange) {
                        visibleWalletRewardCount = count
                    }
                }
            }

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.completionDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                finish(walletCount: walletCount)
            }
            revealTask = nil
        }
    }

    /// Snaps to the completed reveal state (e.g. onDisappear cancel).
    func finish(walletCount: Int) {
        guard !isSequenceComplete else { return }
        visibleWalletRewardCount = walletCount
        areItemsVisible = true
        isSequenceComplete = true
    }

    func cancel(walletCount: Int) {
        revealTask?.cancel()
        revealTask = nil
        if hasStarted {
            finish(walletCount: walletCount)
        }
    }
}
