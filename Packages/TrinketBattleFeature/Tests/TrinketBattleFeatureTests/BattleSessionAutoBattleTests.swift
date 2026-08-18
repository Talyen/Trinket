import Foundation
import Testing
import TrinketBattleRuntime
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionAutoBattleTests {
    @Test func autoBattlePlaysCardsInGreedyOrderUntilDisabled() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let expectedCardIDs = try greedyPlaySequence(from: session)
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastActive: { false },
            isManualInteractionActive: { false },
            playCard: { card in
                let resolution = session.playCard(cardID: card.id)
                guard resolution.didCommit else { return false }
                playedCardIDs.append(card.id)
                if playedCardIDs.count == expectedCardIDs.count {
                    session.isAutoBattleEnabled = false
                }
                return true
            }
        )

        #expect(playedCardIDs == expectedCardIDs)
    }

    @Test func autoBattleRetriesAfterARejectedPlayInsteadOfStopping() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let expectedCardIDs = try greedyPlaySequence(from: session)
        var playAttempts = 0
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastActive: { false },
            isManualInteractionActive: { false },
            playCard: { card in
                playAttempts += 1
                if playAttempts == 1 {
                    return false
                }
                let resolution = session.playCard(cardID: card.id)
                guard resolution.didCommit else { return false }
                playedCardIDs.append(card.id)
                if playedCardIDs.count == expectedCardIDs.count {
                    session.isAutoBattleEnabled = false
                }
                return true
            }
        )

        #expect(playAttempts > expectedCardIDs.count)
        #expect(playedCardIDs == expectedCardIDs)
    }

    @Test func autoBattleResetsOffOnNewBattleWhenRememberIsOff() throws {
        // Concurrency-Safety: `@unchecked Sendable` — test probe is mutated only
        // from the MainActor test body; never shared across isolation domains.
        final class AutoBattleProbe: @unchecked Sendable {
            var remember = false
            var stored = false
            var persistedValues: [Bool] = []
        }

        let probe = AutoBattleProbe()
        let environment = BattleRuntimeDependencies(
            playSFX: { _ in },
            warmSFX: { _, _ in },
            hapticsEnabled: { false },
            effectsVolume: { 0 },
            rememberAutoBattlePreference: { probe.remember },
            autoBattleEnabled: { probe.stored },
            setAutoBattleEnabled: { probe.persistedValues.append($0) },
            shouldAutoSkipUltimateCinematic: { _, _ in false }
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            presentationEnvironment: environment
        )
        let firstConfiguration = try #require(session.activeBattle)

        session.isAutoBattleEnabled = true
        #expect(session.isAutoBattleEnabled)
        #expect(probe.persistedValues.isEmpty)

        session.endBattle()
        let (nextConfiguration, _) = BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed &+ 1,
            hero: firstConfiguration.hero.combatant,
            companion: firstConfiguration.companion.combatant,
            enemy: firstConfiguration.enemy
        )
        #expect(session.activate(nextConfiguration))

        #expect(!session.isAutoBattleEnabled)
        #expect(probe.persistedValues.isEmpty)
    }

    @Test func autoBattleRestoresAndPersistsWhenRememberIsOn() throws {
        // Concurrency-Safety: `@unchecked Sendable` — test probe is mutated only
        // from the MainActor test body; never shared across isolation domains.
        final class AutoBattleProbe: @unchecked Sendable {
            var remember = true
            var stored = true
            var persistedValues: [Bool] = []
        }

        let probe = AutoBattleProbe()
        let environment = BattleRuntimeDependencies(
            playSFX: { _ in },
            warmSFX: { _, _ in },
            hapticsEnabled: { false },
            effectsVolume: { 0 },
            rememberAutoBattlePreference: { probe.remember },
            autoBattleEnabled: { probe.stored },
            setAutoBattleEnabled: { value in
                probe.stored = value
                probe.persistedValues.append(value)
            },
            shouldAutoSkipUltimateCinematic: { _, _ in false }
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            presentationEnvironment: environment
        )
        #expect(session.isAutoBattleEnabled)

        session.isAutoBattleEnabled = false
        #expect(probe.persistedValues == [false])
        #expect(!probe.stored)

        session.isAutoBattleEnabled = true
        #expect(probe.persistedValues == [false, true])

        session.endBattle()
        let (nextConfiguration, _) = BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed &+ 2,
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                actionIntervalTurns: 1,
                abilities: [.slash]
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                actionIntervalTurns: 100,
                abilities: []
            ),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 100,
                actionIntervalTurns: 100,
                abilities: []
            )
        )
        #expect(session.activate(nextConfiguration))
        #expect(session.isAutoBattleEnabled)
    }

    private func greedyPlaySequence(from session: BattleSession) throws -> [Int] {
        var preview = try #require(session.engineState)
        let limit = preview.hand.cards.count(where: { preview.isCardPlayable($0) })
        let policy = GreedyHeuristicPolicy()
        var ids: [Int] = []
        while ids.count < limit, let card = policy.preferredPlayableCard(in: preview) {
            ids.append(card.id)
            _ = try preview.playCard(cardID: card.id, rebuildLog: false)
        }
        return ids
    }
}
