import Foundation
import Testing
@testable import TrinketFeatureSupport

@MainActor
struct RewardRevealSequenceStateTests {
    @Test func `a gold loss remains visible in the reward sequence`() async {
        let state = makeState()
        let count = RewardRevealLootSection.walletRewardCount(gold: -5, materials: [])
        state.start(walletCount: count)
        #expect(await waitUntil { state.isSequenceComplete })
        #expect(state.visibleWalletRewardCount == 1)
    }

    @Test func `cancel finishes A started sequence`() async {
        let clock = ControlledRewardRevealClock()
        let state = RewardRevealSequenceState(clock: clock)
        state.start(walletCount: 2)
        #expect(await waitUntil { clock.isSleeping })
        state.cancel(walletCount: 2)
        clock.advance()
        #expect(state.isSequenceComplete)
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test func `loot reveals together and starts only once without XP callbacks`() async {
        let walletCount = 3
        let clock = ControlledRewardRevealClock()
        let state = RewardRevealSequenceState(clock: clock)
        state.start(walletCount: walletCount)
        #expect(await waitUntil { clock.isSleeping })
        #expect(!state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 0)
        #expect(!state.isSequenceComplete)
        clock.advance()
        #expect(await waitUntil { clock.isSleeping })
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == walletCount)
        #expect(!state.isSequenceComplete)
        clock.advance()
        #expect(await waitUntil { state.isSequenceComplete })
        state.start(walletCount: 5)
        #expect(state.visibleWalletRewardCount == walletCount)
    }

    @Test(arguments: [false, true])
    func `collection confirms once and exits after success`(interrupt: Bool) async {
        let state = RewardCollectionState(clock: TestRewardRevealClock())
        var claims = 0
        var exits = 0
        let action = RewardRevealAction.collect(hapticsEnabled: true, claim: {
            claims += 1
            return true
        }, finish: { exits += 1 })
        state.perform(action)
        #expect(state.isCollected)
        #expect(exits == 0)
        state.perform(action)
        if interrupt {
            state.finish()
        }
        #expect(await waitUntil { exits == 1 })
        state.finish()
        state.perform(action)
        #expect(claims == 1)
        #expect(exits == 1)
        #expect(state.feedbackTrigger == 1)
    }

    @Test func `failed collection stays available without success feedback`() {
        let state = RewardCollectionState(clock: TestRewardRevealClock())
        var exits = 0
        state.perform(.collect(hapticsEnabled: true, claim: { false }, finish: { exits += 1 }))
        state.finish()
        #expect(!state.isCompleting)
        #expect(!state.isCollected)
        #expect(state.feedbackTrigger == 0)
        #expect(exits == 0)
        state.perform(.collect(hapticsEnabled: true, claim: { true }, finish: { exits += 1 }))
        state.finish()
        #expect(exits == 1)
    }

    @Test func `immediate action failure allows retry`() {
        let state = RewardCollectionState()
        var attempts = 0
        state.perform(.immediate {
            attempts += 1
            return false
        })
        #expect(!state.isCompleting)
        #expect(!state.isCollected)
        #expect(attempts == 1)

        state.perform(.immediate {
            attempts += 1
            return true
        })
        #expect(state.isCompleting)
        #expect(attempts == 2)
    }

    private func waitUntil(
        timeout: Duration = .seconds(5),
        condition: @MainActor () -> Bool,
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return true
    }

    private func makeState() -> RewardRevealSequenceState {
        RewardRevealSequenceState(clock: TestRewardRevealClock())
    }
}

private struct TestRewardRevealClock: RewardRevealClock {
    func sleep(for _: Duration) {}
}

@MainActor
private final class ControlledRewardRevealClock: RewardRevealClock {
    private var continuation: CheckedContinuation<Void, Never>?

    var isSleeping: Bool {
        continuation != nil
    }

    func sleep(for _: Duration) async {
        await withCheckedContinuation { continuation = $0 }
    }

    func advance() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}
