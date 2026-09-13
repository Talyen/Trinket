import Foundation
import Testing
@testable import TrinketFeatureSupport

@MainActor
struct RewardRevealSequenceStateTests {
    @Test func `a gold loss remains visible in the reward sequence`() async {
        let state = makeState()
        let count = RewardRevealLootSection.walletRewardCount(gold: -5, materials: [])
        state.start(itemCount: 0, walletCount: count)
        #expect(await waitUntil { state.isSequenceComplete })
        #expect(state.visibleWalletRewardCount == 1)
    }

    @Test func `start completes wallet and item reveal`() async {
        let state = makeState()
        state.start(itemCount: 1, walletCount: 2)
        #expect(await waitUntil { state.isSequenceComplete })
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test func `start is idempotent`() async {
        let state = makeState()
        state.start(itemCount: 1, walletCount: 1)
        #expect(await waitUntil { state.isSequenceComplete })
        state.start(itemCount: 0, walletCount: 3)
        #expect(state.visibleWalletRewardCount == 1)
    }

    @Test func `cancel finishes A started sequence`() async {
        let state = makeState { _ in
            while !Task.isCancelled {
                await Task.yield()
            }
            throw CancellationError()
        }
        state.start(itemCount: 1, walletCount: 2)
        await Task.yield()
        state.cancel(walletCount: 2)
        #expect(state.isSequenceComplete)
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test func `experience bars gate the reveal`() async {
        let singleAwardState = makeState()
        singleAwardState.experienceBarCompleted(requiredCount: 1, itemCount: 0, walletCount: 1)
        #expect(await waitUntil { singleAwardState.isSequenceComplete })
        #expect(singleAwardState.visibleWalletRewardCount == 1)

        let twoAwardState = makeState()
        twoAwardState.experienceBarCompleted(requiredCount: 2, itemCount: 0, walletCount: 1)
        #expect(!twoAwardState.isSequenceComplete)
        twoAwardState.experienceBarCompleted(requiredCount: 2, itemCount: 0, walletCount: 1)
        #expect(await waitUntil { twoAwardState.isSequenceComplete })
        #expect(twoAwardState.visibleWalletRewardCount == 1)
    }

    @Test(arguments: [false, true])
    func `collection confirms once and exits after success`(interrupt: Bool) async {
        let state = RewardCollectionState(clock: TestRewardRevealClock { _ in })
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

    @Test func `immediate actions bypass the collection beat`() {
        let state = RewardCollectionState()
        var completions = 0
        state.perform(.immediate {
            completions += 1
            return true
        })
        state.finish()
        #expect(completions == 1)
        #expect(!state.isCollected)
        #expect(state.feedbackTrigger == 0)
    }

    @Test func `failed collection stays available without success feedback`() {
        let state = RewardCollectionState(clock: TestRewardRevealClock { _ in })
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

    private func makeState(
        sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in },
    ) -> RewardRevealSequenceState {
        RewardRevealSequenceState(clock: TestRewardRevealClock(sleep: sleep))
    }
}

private struct TestRewardRevealClock: RewardRevealClock, Sendable {
    let sleepAction: @Sendable (Duration) async throws -> Void

    init(sleep: @escaping @Sendable (Duration) async throws -> Void) {
        sleepAction = sleep
    }

    func sleep(for duration: Duration) async throws {
        try await sleepAction(duration)
    }
}
