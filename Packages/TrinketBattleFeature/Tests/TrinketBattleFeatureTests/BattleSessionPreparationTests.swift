import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionPreparationTests {
    @Test func `lifecycle transitions update engine and presentation atomically`() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession()
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
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

    @Test func `prepared previews preserve identity and refresh selected presentation`() throws {
        let session = BattleSession()
        let first = preparedConfiguration(key: "first", seed: 17)
        let second = preparedConfiguration(key: "second", seed: 19)
        let firstHandle = try #require(session.createPreparedRun(first))
        let secondHandle = try #require(session.createPreparedRun(second))
        let preview = BattlePreparedPreview(configurations: [first, second], selected: firstHandle)
        session.publishPreparedPreview(preview)
        #expect(session.activeBattle == nil)
        #expect(session.lifecyclePhase == .prepared)
        #expect(session.overlayBattleConfiguration?.id == first.id)
        #expect(session.presentation.configurationID == first.id)
        let revision = session.preparedBattlePresentationRevision
        session.publishPreparedPreview(preview)
        #expect(session.preparedBattlePresentationRevision == revision)
        session.publishPreparedPreview(.init(configurations: [first, second], selected: nil))
        #expect(session.overlayBattleConfiguration == nil)
        session.publishPreparedPreview(.init(configurations: [first, second], selected: secondHandle))
        #expect(session.presentation.configurationID == second.id)
        #expect(session.preparedBattlePresentationRevision > revision)
    }

    @Test func `prepared activation installs its snapshot and keeps the overlay identity`() throws {
        let session = BattleSession()
        defer { session.endBattle() }
        let configuration = preparedConfiguration(key: "activate", seed: 17)
        let handle = try #require(session.createPreparedRun(configuration))
        session.publishPreparedPreview(.init(configurations: [configuration], selected: handle))
        let revision = session.preparedBattlePresentationRevision
        #expect(session.activatePreparedBattle(handle, presentation: .empty))
        #expect(session.activeBattle?.id == configuration.id)
        #expect(session.activeBattle?.rngSeed == 17)
        #expect(session.hasActiveSimulation)
        #expect(session.overlayBattleConfiguration?.id == configuration.id)
        #expect(session.presentation.configurationID == configuration.id)
        #expect(session.preparedBattlePresentationRevision == revision)
        #expect(!session.activatePreparedBattle(handle, presentation: .empty))
        #expect(session.activeBattle?.id == configuration.id)
        #expect(!session.hand.isEmpty)
        #expect(!session.isDealingOpeningHand)
        #expect(session.canAcceptBattleCommands)
    }

    private enum RejectedHandle: CaseIterable { case invalidated, ended, foreign }

    @Test(arguments: RejectedHandle.allCases)
    private func `invalidated ended and foreign preparations cannot activate`(reason: RejectedHandle) throws {
        let session = BattleSession()
        let owner = reason == .foreign ? BattleSession() : session
        let configuration = preparedConfiguration(key: "rejected", seed: 1)
        let handle = try #require(owner.createPreparedRun(configuration))
        switch reason {
        case .invalidated: handle.invalidate()
        case .ended: owner.endBattle()
        case .foreign: break
        }
        #expect(!session.activatePreparedBattle(handle, presentation: .empty))
        #expect(session.activeBattle == nil)
        #expect(!session.hasActiveSimulation)
    }

    @Test func `prepared activation captures reward presentation before skipping combat`() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("test|presentation"), hero: party.hero,
            companion: party.companion, enemy: party.enemy, hasProgressionRewards: true,
        )
        let handle = try #require(session.createPreparedRun(configuration))
        #expect(session.activatePreparedBattle(handle, presentation: presentation))
        #expect(session.presentationContext?.rewardPlan == presentation.rewardPlan)
        #if DEBUG
        session.debugSkipCombat()
        #expect(session.spectacle.outcomePresentation.isVictoryPresented)
        #expect(session.spectacle.outcomePresentation.victorySummaryIfAvailable != nil)
        #endif
    }

    private func preparedConfiguration(key: String, seed: UInt64) -> BattleRunConfiguration {
        let party = BattlePartyFixtures.quickWinParty(heroAbilities: [.slash, .heal, .smite])
        return BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey(key), rngSeed: seed,
            hero: party.hero, companion: party.companion, enemy: party.enemy,
        ).configuration
    }

    private enum StartupInstallation: CaseIterable { case fresh, prepared, restart }

    @Test(arguments: StartupInstallation.allCases)
    private func `opening victory completes after the active registration can be published`(mode: StartupInstallation) async throws {
        let session = BattleSession()
        defer { session.endBattle() }
        var registrationPublished = false
        var completed: [UUID] = []
        let progression = BattleProgressionProbe { configuration, _, _ in
            #expect(registrationPublished)
            completed.append(configuration.id)
            return .completed
        }
        session.connectProgression(to: progression)
        defer { withExtendedLifetime(progression) {} }
        var modifiers = CombatModifierProfile.zero
        modifiers.triggers.healthRegenAboveHalfHealth = 4
        modifiers.triggers.healthRestoredPoisonPercent = 0.5
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 100, abilities: [.slash])
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 1)
        let (_, context) = BattleRunConfigurationTestSupport.make(
            hero: hero, companion: companion, enemy: enemy, stageRewardsAlreadyClaimed: true,
        )
        let configuration = BattleRunConfiguration(
            runKey: mode == .prepared ? BattleRunKey("test|opening-victory") : nil,
            rngSeed: 17,
            hero: .init(combatant: hero, progression: .initial, equipmentLoadout: .init(), modifiers: modifiers, startingHealth: 60),
            companion: .init(combatant: companion, progression: .initial, equipmentLoadout: .init(), modifiers: .zero),
            enemy: enemy, enemyModifiers: .zero,
        )
        switch mode {
        case .fresh:
            #expect(session.activate(configuration, presentation: context))
        case .prepared:
            let handle = try #require(session.createPreparedRun(configuration))
            #expect(session.activatePreparedBattle(handle, presentation: context))
        case .restart:
            #expect(session.activate(preparedConfiguration(key: "original", seed: 1)))
            #expect(session.restart(configuration, presentation: context))
        }
        #expect(session.outcome == .victory)
        #expect(completed.isEmpty)
        registrationPublished = true
        #expect(try await BattleSessionTestSupport.waitUntil { completed == [configuration.id] })
        session.deliverClaimedVictoryIfNeeded()
        #expect(completed == [configuration.id])
    }

    @Test func `replacement opening hand deal retains task ownership after cancellation`() async throws {
        let party = BattlePartyFixtures.quickWinParty(heroAbilities: [.slash, .heal, .smite])
        // 3-2-1 decks deal copies, so the opening hand fills to maxSize from
        // total deck copies — not from unique loadout counts.
        let expectedOpeningHandCount = min(
            BattleHand.maxSize,
            CombatDeck.defaultAbilities(from: party.hero.abilityLoadout).count
                + CombatDeck.defaultAbilities(from: party.companion.abilityLoadout).count,
        )
        let session = BattleSession()
        let (initialConfiguration, _) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
        )
        let (replacementConfiguration, _) = BattleRunConfigurationTestSupport.make(
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
        )

        #expect(session.activate(initialConfiguration))
        #expect(session.restart(replacementConfiguration))

        #expect(try await BattleSessionTestSupport.waitUntil { !session.hand.isEmpty })

        #expect(!session.hand.isEmpty)
        #expect(!session.isDealingOpeningHand)

        #expect(try await BattleSessionTestSupport.waitUntil { !session.isDealingOpeningHand })

        #expect(session.hand.count == expectedOpeningHandCount)
        #expect(!session.isDealingOpeningHand)
        #expect(session.activeBattle?.id == replacementConfiguration.id)
    }

    @Test func `hand play gate follows the command window instead of the projection list`() async throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession()
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
        )

        #expect(session.activate(configuration))
        #expect(try await BattleSessionTestSupport.waitUntil { !session.isDealingOpeningHand })

        let card = try #require(session.hand.first(where: session.isCardPlayable))
        try #expect(session.presentation.playableCardIDs.contains(card.id))
        try #expect(session.isHandCardPlayable(card))

        // A refused-command window keeps the projection list but must not
        // advertise a play accessibility activation would be rejected for.
        session.setSuspendedForScenePhase(true)
        try #expect(session.presentation.playableCardIDs.contains(card.id))
        try #expect(!session.isHandCardPlayable(card))

        session.setSuspendedForScenePhase(false)
        try #expect(session.isHandCardPlayable(card))
    }
}
