import Foundation
import Testing
@testable import TrinketFeatureSupport

@MainActor
struct RewardRevealSequenceStateTests {
    @Test func `start completes wallet and item reveal`() async {
        let state = RewardRevealSequenceState(sleep: { _ in })
        state.start(itemCount: 1, walletCount: 2)
        #expect(await waitUntil { state.isSequenceComplete })
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test func `start is idempotent`() async {
        let state = RewardRevealSequenceState(sleep: { _ in })
        state.start(itemCount: 1, walletCount: 1)
        #expect(await waitUntil { state.isSequenceComplete })
        state.start(itemCount: 0, walletCount: 3)
        #expect(state.visibleWalletRewardCount == 1)
    }

    @Test func `cancel finishes A started sequence`() async {
        let state = RewardRevealSequenceState(sleep: { _ in
            while !Task.isCancelled {
                await Task.yield()
            }
            throw CancellationError()
        })
        state.start(itemCount: 1, walletCount: 2)
        await Task.yield()
        state.cancel(walletCount: 2)
        #expect(state.isSequenceComplete)
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test func `experience bars gate the reveal`() async {
        let singleAwardState = RewardRevealSequenceState(sleep: { _ in })
        singleAwardState.experienceBarCompleted(requiredCount: 1, itemCount: 0, walletCount: 1)
        #expect(await waitUntil { singleAwardState.isSequenceComplete })
        #expect(singleAwardState.visibleWalletRewardCount == 1)

        let twoAwardState = RewardRevealSequenceState(sleep: { _ in })
        twoAwardState.experienceBarCompleted(requiredCount: 2, itemCount: 0, walletCount: 1)
        #expect(!twoAwardState.isSequenceComplete)
        twoAwardState.experienceBarCompleted(requiredCount: 2, itemCount: 0, walletCount: 1)
        #expect(await waitUntil { twoAwardState.isSequenceComplete })
        #expect(twoAwardState.visibleWalletRewardCount == 1)
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool,
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            await Task.yield()
        }
        return true
    }
}
