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

    @Test func `start completes wallet and item reveal`() async {
        let state = makeState()
        state.start(walletCount: 2)
        #expect(await waitUntil { state.isSequenceComplete })
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test func `start is idempotent`() async {
        let state = makeState()
        state.start(walletCount: 1)
        #expect(await waitUntil { state.isSequenceComplete })
        state.start(walletCount: 3)
        #expect(state.visibleWalletRewardCount == 1)
    }

    @Test func `cancel finishes A started sequence`() async {
        let state = makeState { _ in
            while !Task.isCancelled {
                await Task.yield()
            }
            throw CancellationError()
        }
        state.start(walletCount: 2)
        await Task.yield()
        state.cancel(walletCount: 2)
        #expect(state.isSequenceComplete)
        #expect(state.areItemsVisible)
        #expect(state.visibleWalletRewardCount == 2)
    }

    @Test(arguments: [0, 1, 3])
    func `loot reveals together and becomes ready without XP callbacks`(walletCount: Int) async {
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

    @Test func `collection exits after one brief confirmation beat`() async {
        let clock = ControlledRewardRevealClock()
        let state = RewardCollectionState(clock: clock)
        var exits = 0
        state.perform(.collect(hapticsEnabled: true, claim: { true }, finish: { exits += 1 }))
        #expect(await waitUntil { clock.isSleeping })
        #expect(state.isCollected)
        #expect(exits == 0)
        #expect(clock.requestedDurations == [.milliseconds(350)])
        clock.advance()
        #expect(await waitUntil { exits == 1 })
        #expect(!clock.isSleeping)
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

@MainActor
private final class ControlledRewardRevealClock: RewardRevealClock {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var requestedDurations: [Duration] = []

    var isSleeping: Bool {
        continuation != nil
    }

    func sleep(for duration: Duration) async {
        requestedDurations.append(duration)
        await withCheckedContinuation { continuation = $0 }
    }

    func advance() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}
