import Foundation
import Testing
@testable import TrinketFeatureSupport

@MainActor
struct RewardRevealSequenceStateTests {
    @Test func startCompletesWalletAndItemReveal() async {
        let state = RewardRevealSequenceState(sleep: { _ in })
        state.start(itemCount: 1, walletCount: 2)
        #expect(await waitUntil { state.isSequenceComplete })
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test func startIsIdempotent() async {
        let state = RewardRevealSequenceState(sleep: { _ in })
        state.start(itemCount: 1, walletCount: 1)
        #expect(await waitUntil { state.isSequenceComplete })
        state.start(itemCount: 0, walletCount: 3)
        #expect(state.visibleWalletRewardCount == 1)
    }

    @Test func cancelFinishesAStartedSequence() async {
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

    @Test func experienceBarsGateTheReveal() async {
        let state = RewardRevealSequenceState(sleep: { _ in })
        state.experienceBarCompleted(requiredCount: 2, itemCount: 0, walletCount: 1)
        #expect(!state.isSequenceComplete)
        state.experienceBarCompleted(requiredCount: 2, itemCount: 0, walletCount: 1)
        #expect(await waitUntil { state.isSequenceComplete })
        #expect(state.visibleWalletRewardCount == 1)
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            await Task.yield()
        }
        return true
    }
}
