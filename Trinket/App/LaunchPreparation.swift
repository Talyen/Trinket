import SwiftUI

/// Single owner for launch-gating state behind the launch cover.
///
/// Previously `PreparedAppRoot` held eight separate `@State` flags with three
/// derived gates recomputed across the `ZStack`. Collapsing them here keeps one
/// state machine (`resources ∧ minimumTime ∧ layouts ∧ castEffects ∧ delay`)
/// with an explicit acknowledge API so the latch is testable without mounting
/// the full root.
@MainActor
@Observable
final class LaunchPreparation {
    var isResourcePreparationComplete = false
    var isMinimumLoadingTimeComplete = false
    var areCastEffectsPrepared = false
    var didWarmHiddenTabs = false
    var didLayOutSelectedRoot = false
    var didCompleteLaunchPreparation = false
    var retainedLaunchEncounterID: ObjectIdentifier?
    var isPreparationDelayComplete: Bool

    init(isPreparationDelayComplete: Bool) {
        self.isPreparationDelayComplete = isPreparationDelayComplete
    }

    func acknowledge(_ event: LaunchPreparationEvent) {
        switch event {
        case .resourcesReady:
            isResourcePreparationComplete = true
        case .minimumLoadingTimeComplete:
            isMinimumLoadingTimeComplete = true
        case .castEffectsPrepared:
            areCastEffectsPrepared = true
        case .hiddenTabsWarmed:
            didWarmHiddenTabs = true
        case .selectedRootLaidOut:
            didLayOutSelectedRoot = true
        case .preparationDelayComplete:
            isPreparationDelayComplete = true
        }
    }

    var shouldMountRoot: Bool {
        isResourcePreparationComplete && isMinimumLoadingTimeComplete
    }

    func areRootLayoutsPrepared(starterSelectionComplete: Bool) -> Bool {
        shouldMountRoot
            && didLayOutSelectedRoot
            && (!starterSelectionComplete || didWarmHiddenTabs)
    }

    func isPreparationComplete(starterSelectionComplete: Bool) -> Bool {
        areRootLayoutsPrepared(starterSelectionComplete: starterSelectionComplete)
            && areCastEffectsPrepared
            && isPreparationDelayComplete
    }
}

enum LaunchPreparationEvent {
    case resourcesReady
    case minimumLoadingTimeComplete
    case castEffectsPrepared
    case hiddenTabsWarmed
    case selectedRootLaidOut
    case preparationDelayComplete
}

extension EnvironmentValues {
    @Entry var isLaunchPresentationReady = true
}
