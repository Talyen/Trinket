import Foundation
import Observation
import SwiftUI
import TrinketDesignSystem

/// Shared timing owner for victory / mystery reward and unlock reveal sequences.
@MainActor
@Observable
public final class RewardRevealSequenceState {
    public private(set) var visibleWalletRewardCount = 0
    public private(set) var areItemsVisible = false
    public private(set) var visibleChromeStepCount = 0
    public private(set) var isSequenceComplete = false
    private var completedExperienceBarCount = 0
    private var hasStarted = false
    private var revealTask: Task<Void, Never>?

    public init() {}

    public func start(itemCount: Int, walletCount: Int) {
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

    public func experienceBarCompleted(
        requiredCount: Int,
        itemCount: Int,
        walletCount: Int
    ) {
        completedExperienceBarCount += 1
        guard completedExperienceBarCount >= requiredCount else { return }
        start(itemCount: itemCount, walletCount: walletCount)
    }

    /// Staggered chrome reveal (eyebrow → title → subtitle → art) for unlock shells.
    public func startChromeSteps(_ stepCount: Int) {
        guard !hasStarted else { return }
        hasStarted = true
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            let clock = SuspendingClock()
            let steps = max(0, stepCount)

            if steps > 0 {
                try? await clock.sleep(for: .seconds(TrinketMotion.Reward.itemRevealDelay))
                guard !Task.isCancelled else { return }

                for count in 1 ... steps {
                    if count > 1 {
                        try? await clock.sleep(for: .seconds(TrinketMotion.Reward.resourceStagger))
                        guard !Task.isCancelled else { return }
                    }
                    withAnimation(TrinketMotion.Reward.reveal) {
                        visibleChromeStepCount = count
                    }
                }
            }

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.completionDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                finishChrome(stepCount: steps)
            }
            revealTask = nil
        }
    }

    public func chromeOpacity(visibleFrom step: Int) -> Double {
        visibleChromeStepCount >= step ? 1 : 0
    }

    /// Snaps to the completed reveal state (e.g. onDisappear cancel).
    public func finish(walletCount: Int) {
        guard !isSequenceComplete else { return }
        visibleWalletRewardCount = walletCount
        areItemsVisible = true
        isSequenceComplete = true
    }

    public func finishChrome(stepCount: Int) {
        guard !isSequenceComplete else { return }
        visibleChromeStepCount = max(0, stepCount)
        isSequenceComplete = true
    }

    public func cancel(walletCount: Int) {
        revealTask?.cancel()
        revealTask = nil
        if hasStarted {
            finish(walletCount: walletCount)
        }
    }

    public func cancelChrome(stepCount: Int) {
        revealTask?.cancel()
        revealTask = nil
        if hasStarted {
            finishChrome(stepCount: stepCount)
        }
    }
}
