import Foundation
import Testing
@testable import TrinketFeatureSupport

struct LaunchPreparationTests {
    private final class DummyToken {}

    @Test
    @MainActor
    func `initial gating state`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: false)
        #expect(!prep.isResourcePreparationComplete)
        #expect(!prep.isMinimumLoadingTimeComplete)
        #expect(!prep.areCastEffectsPrepared)
        #expect(!prep.didWarmHiddenTabs)
        #expect(!prep.didLayOutSelectedRoot)
        #expect(!prep.didCompleteLaunchPreparation)
        #expect(prep.launchEncounterToken == nil)
        #expect(!prep.isPreparationDelayComplete)
        #expect(!prep.shouldMountRoot)
        #expect(!prep.areRootLayoutsPrepared(starterSelectionComplete: true))
        #expect(!prep.areRootLayoutsPrepared(starterSelectionComplete: false))
        #expect(!prep.isPreparationComplete(starterSelectionComplete: true))
    }

    @Test
    @MainActor
    func `initial gating state when delay zero`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: true)
        #expect(prep.isPreparationDelayComplete)
        #expect(!prep.shouldMountRoot)
    }

    @Test
    @MainActor
    func `should mount root requires both resources and minimum loading time`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: true)

        prep.acknowledge(.resourcesReady)
        #expect(prep.isResourcePreparationComplete)
        #expect(!prep.shouldMountRoot)

        prep.acknowledge(.minimumLoadingTimeComplete)
        #expect(prep.isMinimumLoadingTimeComplete)
        #expect(prep.shouldMountRoot)
    }

    @Test
    @MainActor
    func `are root layouts prepared differentiates starter flow`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: true)
        prep.acknowledge(.resourcesReady)
        prep.acknowledge(.minimumLoadingTimeComplete)
        prep.acknowledge(.selectedRootLaidOut)

        // For first-run/starter players, hidden tabs do not gate layout readiness.
        #expect(prep.areRootLayoutsPrepared(starterSelectionComplete: false))
        // For completed starter players, hidden tabs MUST be warmed.
        #expect(!prep.areRootLayoutsPrepared(starterSelectionComplete: true))

        prep.acknowledge(.hiddenTabsWarmed)
        #expect(prep.areRootLayoutsPrepared(starterSelectionComplete: true))
    }

    @Test
    @MainActor
    func `is preparation complete requires all five gates`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: false)
        prep.acknowledge(.resourcesReady)
        prep.acknowledge(.minimumLoadingTimeComplete)
        prep.acknowledge(.selectedRootLaidOut)
        prep.acknowledge(.hiddenTabsWarmed)
        #expect(!prep.isPreparationComplete(starterSelectionComplete: true))

        prep.acknowledge(.castEffectsPrepared)
        #expect(!prep.isPreparationComplete(starterSelectionComplete: true))

        prep.acknowledge(.preparationDelayComplete)
        #expect(prep.isPreparationComplete(starterSelectionComplete: true))
    }

    @Test
    @MainActor
    func `launch encounter token and completion latching`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: true)
        let dummy = DummyToken()
        let token = ObjectIdentifier(dummy)

        prep.acknowledge(.launchEncounterTokenChanged(token))
        #expect(prep.launchEncounterToken == token)

        prep.acknowledge(.launchPreparationComplete)
        #expect(prep.didCompleteLaunchPreparation)

        prep.acknowledge(.launchEncounterTokenChanged(nil))
        #expect(prep.launchEncounterToken == nil)
        #expect(prep.didCompleteLaunchPreparation)
    }
}
