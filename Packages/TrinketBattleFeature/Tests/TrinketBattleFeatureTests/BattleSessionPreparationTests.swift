import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketTestSupport
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionPreparationTests {
    @Test func lifecycleTransitionsUpdateEngineAndPresentationAtomically() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0)
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.activate(configuration))
        #expect(session.activeBattle?.id == configuration.id)
        #expect(session.hasActiveSimulation)
        #expect(session.lifecyclePhase == .active)
        #expect(session.presentation.configurationID == configuration.id)

        session.endBattle()

        #expect(session.activeBattle == nil)
        #expect(!session.hasActiveSimulation)
        #expect(session.lifecyclePhase == .idle)
        #expect(session.presentation.configurationID == nil)
    }

    @Test func preparedBattlePresentationRevisionChangesOnlyForReplacedRuns() {
        let party = BattlePartyFixtures.quickWinParty()
        let runKey = BattleRunKey("test|prepared-run")
        let session = BattleSession(openingHandDrawStagger: 0)
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(configuration))
        let initialRevision = session.preparedBattlePresentationRevision
        #expect(initialRevision == 1)

        #expect(session.prepareBattleRun(configuration))
        #expect(session.preparedBattlePresentationRevision == initialRevision)

        let (replacement, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        #expect(session.prepareBattleRun(replacement))
        #expect(session.preparedBattlePresentationRevision == initialRevision + 1)
    }

    @Test func activatePreparedBattleInstallsThePreparedEngineSnapshot() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0)
        let runKey = BattleRunKey("test|prepared-activate")
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 17,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(configuration))
        #expect(
            session.activatePreparedBattle(
                runKey: runKey,
                heroID: party.hero.id,
                companionID: party.companion.id,
                enemyID: party.enemy.id
            )
        )
        #expect(session.activeBattle?.id == configuration.id)
        #expect(session.activeBattle?.rngSeed == 17)
        #expect(session.hasActiveSimulation)
        #expect(!session.hasPreparedRun(runKey))
        #expect(session.lifecyclePhase == .active)
        #expect(session.overlayBattleConfiguration?.id == configuration.id)
        #expect(session.presentation.configurationID == configuration.id)
    }

    @Test func prepareInstallsOverlayPresentationForASingleRun() {
        let party = BattlePartyFixtures.quickWinParty()
        let runKey = BattleRunKey("test|prepared-overlay")
        let session = BattleSession(openingHandDrawStagger: 0)
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(configuration))
        #expect(session.overlayBattleConfiguration?.id == configuration.id)
        #expect(session.presentation.configurationID == configuration.id)
        #expect(session.activeBattle == nil)
        #expect(!session.hasActiveSimulation)
        #expect(session.lifecyclePhase == .prepared)
    }

    @Test func overlayBattleConfigurationRequiresASinglePreparedRun() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0)
        let (first, _) = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("test|prepared-overlay-a"),
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        let (second, _) = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("test|prepared-overlay-b"),
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(first))
        #expect(session.overlayBattleConfiguration?.id == first.id)
        #expect(session.prepareBattleRun(second))
        #expect(session.overlayBattleConfiguration == nil)
    }

    @Test func activatePreparedBattleKeepsOverlayConfigurationIdentity() {
        let party = BattlePartyFixtures.quickWinParty()
        let runKey = BattleRunKey("test|prepared-overlay-activate")
        let session = BattleSession(openingHandDrawStagger: 0)
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(configuration))
        let overlayID = session.overlayBattleConfiguration?.id
        let preparedRevision = session.preparedBattlePresentationRevision

        #expect(
            session.activatePreparedBattle(
                runKey: runKey,
                heroID: party.hero.id,
                companionID: party.companion.id,
                enemyID: party.enemy.id
            )
        )
        #expect(session.overlayBattleConfiguration?.id == overlayID)
        #expect(session.activeBattle?.id == overlayID)
        #expect(session.presentation.configurationID == overlayID)
        #expect(session.preparedBattlePresentationRevision == preparedRevision)
    }

    @Test func preparedActivationHoldsOpeningHandDealUntilOverlayFadeCompletes() async throws {
        let party = BattlePartyFixtures.quickWinParty(heroAbilities: [.slash, .heal, .smite])
        let session = BattleSession(openingHandDrawStagger: 0.01)
        let runKey = BattleRunKey("test|prepared-overlay-deal-hold")
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(configuration))
        #expect(
            session.activatePreparedBattle(
                runKey: runKey,
                heroID: party.hero.id,
                companionID: party.companion.id,
                enemyID: party.enemy.id
            )
        )

        #expect(session.hand.isEmpty)
        #expect(session.isDealingOpeningHand)
        let dealtDuringFade = try await BattleSessionTestSupport.waitUntil(
            timeout: .milliseconds(100)
        ) {
            !session.hand.isEmpty
        }
        #expect(!dealtDuringFade)
        #expect(session.isDealingOpeningHand)
        #expect(try await BattleSessionTestSupport.waitUntil { !session.hand.isEmpty })
        #expect(try await BattleSessionTestSupport.waitUntil { !session.isDealingOpeningHand })
    }

    @Test func activatePreparedBattleKeepsOverlayPresentationContextForSkipCombat() {
        let party = BattlePartyFixtures.quickWinParty()
        let runKey = BattleRunKey("test|prepared-overlay-context")
        let session = BattleSession(openingHandDrawStagger: 0, outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = 0
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            hasProgressionRewards: true
        )

        #expect(session.prepareBattleRun(configuration))
        session.installPresentationContext(presentation)

        #expect(
            session.activatePreparedBattle(
                runKey: runKey,
                heroID: party.hero.id,
                companionID: party.companion.id,
                enemyID: party.enemy.id
            )
        )
        #expect(session.presentationContext != nil)

        #if DEBUG
        session.debugSkipCombat()
        #expect(session.spectacle.isShowingVictory)
        #expect(session.spectacle.victorySummary != nil)
        #endif
    }

    @Test func replacementOpeningHandDealRetainsTaskOwnershipAfterCancellation() async throws {
        let party = BattlePartyFixtures.quickWinParty(heroAbilities: [.slash, .heal, .smite])
        let expectedOpeningHandCount = min(
            BattleHand.maxSize,
            party.hero.abilityLoadout.abilities.count
                + party.companion.abilityLoadout.abilities.count
        )
        let session = BattleSession(openingHandDrawStagger: 0.05)
        let (initialConfiguration, _) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        let (replacementConfiguration, _) = BattleRunConfigurationTestSupport.make(
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.activate(initialConfiguration))
        #expect(session.restart(replacementConfiguration))

        #expect(try await BattleSessionTestSupport.waitUntil { !session.hand.isEmpty })

        #expect(!session.hand.isEmpty)
        #expect(session.isDealingOpeningHand)

        #expect(try await BattleSessionTestSupport.waitUntil { !session.isDealingOpeningHand })

        #expect(session.hand.count == expectedOpeningHandCount)
        #expect(!session.isDealingOpeningHand)
        #expect(session.activeBattle?.id == replacementConfiguration.id)
    }
}
