import Foundation
import Observation
import SwiftUI
import TrinketDesignSystem

public protocol RewardRevealClock: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct SuspendingRewardRevealClock: RewardRevealClock {
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try await SuspendingClock().sleep(for: duration)
    }
}

@MainActor
@Observable
public final class RewardRevealSequenceState {
    public private(set) var visibleWalletRewardCount = 0
    public private(set) var areItemsVisible = false
    public private(set) var isSequenceComplete = false
    private var completedExperienceBarCount = 0
    private var hasStarted = false
    private var revealTask: Task<Void, Never>?
    private let clock: any RewardRevealClock

    public convenience init() {
        self.init(clock: SuspendingRewardRevealClock())
    }

    init(clock: any RewardRevealClock) {
        self.clock = clock
    }

    public func start(itemCount: Int, walletCount: Int) {
        guard !hasStarted else { return }
        hasStarted = true
        revealTask?.cancel()
        revealTask = Task { @MainActor in
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
        walletCount: Int,
    ) {
        completedExperienceBarCount += 1
        guard completedExperienceBarCount >= requiredCount else { return }
        start(itemCount: itemCount, walletCount: walletCount)
    }

    private func finish(walletCount: Int) {
        guard !isSequenceComplete else { return }
        visibleWalletRewardCount = walletCount
        areItemsVisible = true
        isSequenceComplete = true
    }

    public func cancel(walletCount: Int) {
        revealTask?.cancel()
        revealTask = nil
        if hasStarted {
            finish(walletCount: walletCount)
        }
    }
}
