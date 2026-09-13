import Foundation
import Observation
import TrinketDesignSystem

public enum RewardRevealAction {
    case immediate(() -> Bool)
    case collect(hapticsEnabled: Bool, claim: () -> Bool, finish: () -> Void)

    var hapticsEnabled: Bool {
        guard case let .collect(enabled, _, _) = self else { return false }
        return enabled
    }
}

@MainActor
@Observable
final class RewardCollectionState {
    private enum Phase {
        case ready, claiming, collected, finished, completedImmediately
    }

    private var phase = Phase.ready
    private(set) var hasGathered = false
    private(set) var feedbackTrigger = 0
    private var finishAction: (() -> Void)?
    private var task: Task<Void, Never>?
    private let clock: any RewardRevealClock

    var isCompleting: Bool {
        phase != .ready
    }

    var isCollected: Bool {
        phase == .collected || phase == .finished
    }

    init(clock: any RewardRevealClock = SuspendingRewardRevealClock()) {
        self.clock = clock
    }

    func perform(_ action: RewardRevealAction) {
        guard phase == .ready else { return }
        phase = .claiming
        switch action {
        case let .immediate(complete):
            phase = complete() ? .completedImmediately : .ready
        case let .collect(_, claim, finish):
            guard claim() else {
                phase = .ready
                return
            }
            finishAction = finish
            phase = .collected
            feedbackTrigger &+= 1
            task = Task { @MainActor [weak self, clock] in
                do {
                    try await clock.sleep(for: .seconds(TrinketMotion.Reward.collectionLiftDuration))
                    guard !Task.isCancelled else { return }
                    self?.hasGathered = true
                    try await clock.sleep(for: .seconds(
                        TrinketMotion.Reward.collectionDuration - TrinketMotion.Reward.collectionLiftDuration,
                    ))
                    guard !Task.isCancelled else { return }
                    self?.finish()
                } catch {}
            }
        }
    }

    func finish() {
        guard phase == .collected else { return }
        phase = .finished
        task?.cancel()
        task = nil
        let action = finishAction
        finishAction = nil
        action?()
    }
}
