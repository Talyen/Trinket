import SwiftUI

/// Single owner for launch-gating state behind the launch cover.
///
/// Collapsing launch gates here maintains one observable state machine
/// (`resources ∧ minimumTime ∧ layouts ∧ castEffects ∧ delay`) with an explicit
/// acknowledge API. All mutations go through `acknowledge(_:)`; direct writes
/// from views are a defect.
@MainActor
@Observable
public final class LaunchPreparation {
    public private(set) var isResourcePreparationComplete = false
    public private(set) var isMinimumLoadingTimeComplete = false
    public private(set) var areCastEffectsPrepared = false
    public private(set) var didWarmHiddenTabs = false
    public private(set) var didLayOutSelectedRoot = false
    public private(set) var didCompleteLaunchPreparation = false
    /// Non-retaining identity token for the encounter open at launch completion.
    /// `ObjectIdentifier` does not retain; it only captures identity once so later
    /// encounters cannot reopen the cover (see ui-performance launch cover rules).
    public private(set) var launchEncounterToken: ObjectIdentifier?
    public private(set) var isPreparationDelayComplete: Bool

    public init(isPreparationDelayComplete: Bool) {
        self.isPreparationDelayComplete = isPreparationDelayComplete
    }

    public func acknowledge(_ event: LaunchPreparationEvent) {
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
        case .launchPreparationComplete:
            didCompleteLaunchPreparation = true
        case let .launchEncounterTokenChanged(token):
            launchEncounterToken = token
        }
    }

    public var shouldMountRoot: Bool {
        isResourcePreparationComplete && isMinimumLoadingTimeComplete
    }

    public func areRootLayoutsPrepared(starterSelectionComplete: Bool) -> Bool {
        shouldMountRoot
            && didLayOutSelectedRoot
            && (!starterSelectionComplete || didWarmHiddenTabs)
    }

    public func isPreparationComplete(starterSelectionComplete: Bool) -> Bool {
        areRootLayoutsPrepared(starterSelectionComplete: starterSelectionComplete)
            && areCastEffectsPrepared
            && isPreparationDelayComplete
    }
}

public enum LaunchPreparationEvent: Sendable, Equatable {
    case resourcesReady
    case minimumLoadingTimeComplete
    case castEffectsPrepared
    case hiddenTabsWarmed
    case selectedRootLaidOut
    case preparationDelayComplete
    case launchPreparationComplete
    case launchEncounterTokenChanged(ObjectIdentifier?)
}

public extension EnvironmentValues {
    /// Defaults to ready so previews and isolated sheets that never mount
    /// PreparedAppRoot still present content. Production always overrides this
    /// from the root (initially false until the launch latch completes).
    @Entry var isLaunchPresentationReady = true
}
