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
    private var hasStarted = false
    private var revealTask: Task<Void, Never>?
    private let clock: any RewardRevealClock

    public convenience init() {
        self.init(clock: SuspendingRewardRevealClock())
    }

    init(clock: any RewardRevealClock) {
        self.clock = clock
    }

    public func start(walletCount: Int) {
        guard !hasStarted else { return }
        hasStarted = true
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.entranceDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.lootReveal) {
                areItemsVisible = true
                visibleWalletRewardCount = walletCount
            }
            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.revealDuration))
            guard !Task.isCancelled else { return }
            finish(walletCount: walletCount)
            revealTask = nil
        }
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
