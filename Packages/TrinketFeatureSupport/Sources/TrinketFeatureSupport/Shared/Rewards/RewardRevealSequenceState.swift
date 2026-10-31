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
    private enum Phase {
        case ready, waiting, revealing, complete
    }

    public private(set) var visibleWalletRewardCount = 0
    public var areItemsVisible: Bool {
        phase == .revealing || phase == .complete
    }

    public var isSequenceComplete: Bool {
        phase == .complete
    }

    private var phase = Phase.ready
    private var latestWalletCount = 0
    private var revealedItemIDs: Set<String> = []
    private var suppressesExceptionalReveals = false
    private var revealTask: Task<Void, Never>?
    private let clock: any RewardRevealClock

    public convenience init() {
        self.init(clock: SuspendingRewardRevealClock())
    }

    init(clock: any RewardRevealClock) {
        self.clock = clock
    }

    func claimExceptionalReveal(itemID: String, isExceptional: Bool) -> Bool {
        guard areItemsVisible, isExceptional, !suppressesExceptionalReveals else { return false }
        return revealedItemIDs.insert(itemID).inserted
    }

    func skipExceptionalReveal(itemID: String?) {
        if let itemID {
            revealedItemIDs.insert(itemID)
        }
    }

    func suppressExceptionalReveals() {
        suppressesExceptionalReveals = true
    }

    public func start(walletCount: Int) {
        guard phase == .ready else { return }
        phase = .waiting
        latestWalletCount = walletCount
        revealTask = Task { @MainActor in
            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.entranceDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.lootReveal) {
                phase = .revealing
                visibleWalletRewardCount = latestWalletCount
            }
            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.revealDuration))
            guard !Task.isCancelled else { return }
            finish(walletCount: latestWalletCount)
            revealTask = nil
        }
    }

    private func finish(walletCount: Int) {
        guard phase != .complete else { return }
        visibleWalletRewardCount = walletCount
        phase = .complete
    }

    public func updateWalletCount(_ count: Int) {
        latestWalletCount = count
        guard areItemsVisible, count > visibleWalletRewardCount else { return }
        withAnimation(TrinketMotion.Reward.lootReveal) {
            visibleWalletRewardCount = count
        }
    }

    public func cancel(walletCount: Int) {
        revealTask?.cancel()
        revealTask = nil
        if phase != .ready {
            finish(walletCount: walletCount)
        }
    }
}
