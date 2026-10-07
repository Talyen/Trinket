import Testing
@testable import TrinketFeatureSupport

struct LaunchPreparationTests {
    private final class DummyToken {}

    private static let requiredGates: [LaunchPreparationEvent] = [
        .resourcesReady, .minimumLoadingTimeComplete, .selectedRootLaidOut,
        .hiddenTabsWarmed, .castEffectsPrepared, .preparationDelayComplete,
    ]

    @Test
    @MainActor
    func `should mount root requires both resources and minimum loading time`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: true)

        prep.acknowledge(.resourcesReady)
        #expect(!prep.shouldMountRoot)

        prep.acknowledge(.minimumLoadingTimeComplete)
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
        prep.acknowledge(.castEffectsPrepared)
        #expect(prep.isPreparationComplete(starterSelectionComplete: false))
        #expect(!prep.isPreparationComplete(starterSelectionComplete: true))

        prep.acknowledge(.hiddenTabsWarmed)
        #expect(prep.areRootLayoutsPrepared(starterSelectionComplete: true))
    }

    @Test(arguments: Self.requiredGates)
    @MainActor
    func `each missing gate holds launch until acknowledged`(missing: LaunchPreparationEvent) {
        let prep = LaunchPreparation(isPreparationDelayComplete: false)
        for gate in Self.requiredGates where gate != missing {
            prep.acknowledge(gate)
        }
        #expect(!prep.isPreparationComplete(starterSelectionComplete: true))
        prep.acknowledge(missing)
        #expect(prep.isPreparationComplete(starterSelectionComplete: true))
    }

    @Test
    @MainActor
    func `launch encounter token and completion latching`() {
        let prep = LaunchPreparation(isPreparationDelayComplete: true)
        #expect(!prep.didCompleteLaunchPreparation)
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
