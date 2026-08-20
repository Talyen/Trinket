import Foundation
import Testing
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionAutoBattleTests {
    @Test func interactionStateBlocksCombatantTapsDuringTapLiftAndPress() {
        let state = BattleInteractionState()
        #expect(!state.blocksCombatantTaps)

        state.autoLiftCardID = 42
        #expect(state.blocksCombatantTaps)

        state.autoLiftCardID = nil
        state.suppressCombatantTaps = true
        #expect(state.blocksCombatantTaps)
    }

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

    @Test func autoBattleResumesAfterManualInteractionClears() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        var remainingBlocks = 3
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastActive: { false },
            isManualInteractionActive: {
                guard remainingBlocks > 0 else { return false }
                remainingBlocks -= 1
                return true
            },
            playCard: { card in
                let resolution = session.playCard(cardID: card.id)
                guard resolution.didCommit else { return false }
                playedCardIDs.append(card.id)
                session.isAutoBattleEnabled = false
                return true
            }
        )

        #expect(!playedCardIDs.isEmpty)
        #expect(remainingBlocks == 0)
    }

    @Test func autoBattleResumesAfterCardCastClears() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        var remainingBlocks = 3
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastActive: {
                guard remainingBlocks > 0 else { return false }
                remainingBlocks -= 1
                return true
            },
            isManualInteractionActive: { false },
            playCard: { card in
                let resolution = session.playCard(cardID: card.id)
                guard resolution.didCommit else { return false }
                playedCardIDs.append(card.id)
                session.isAutoBattleEnabled = false
                return true
            }
        )

        #expect(!playedCardIDs.isEmpty)
        #expect(remainingBlocks == 0)
    }

    @Test func autoBattleDoesNotPlayWhileAbilityOverlayIsOpenAfterCastWait() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        var remainingCastBlocks = 2
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        let driver = Task { @MainActor in
            await session.driveAutoBattle(
                isCardCastActive: {
                    guard remainingCastBlocks > 0 else { return false }
                    remainingCastBlocks -= 1
                    session.overlayAbilityDetail = .slash
                    return true
                },
                isManualInteractionActive: { false },
                playCard: { card in
                    let resolution = session.playCard(cardID: card.id)
                    guard resolution.didCommit else { return false }
                    playedCardIDs.append(card.id)
                    session.isAutoBattleEnabled = false
                    return true
                }
            )
        }

        try await Task.sleep(for: .milliseconds(40))
        #expect(playedCardIDs.isEmpty)
        #expect(remainingCastBlocks == 0)
        #expect(session.overlayAbilityDetail != nil)

        session.overlayAbilityDetail = nil
        #expect(try await BattleSessionTestSupport.waitUntil { !playedCardIDs.isEmpty })
        _ = await driver.result
    }

    @Test func autoBattleDoesNotPlayDuringSustainedManualInteraction() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        var interacting = true
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        let driver = Task { @MainActor in
            await session.driveAutoBattle(
                isCardCastActive: { false },
                isManualInteractionActive: { interacting },
                playCard: { card in
                    let resolution = session.playCard(cardID: card.id)
                    guard resolution.didCommit else { return false }
                    playedCardIDs.append(card.id)
                    session.isAutoBattleEnabled = false
                    return true
                }
            )
        }

        try await Task.sleep(for: .milliseconds(40))
        #expect(playedCardIDs.isEmpty)

        interacting = false
        #expect(try await BattleSessionTestSupport.waitUntil { !playedCardIDs.isEmpty })
        _ = await driver.result
    }

    @Test func autoBattleResumesAfterStuckCastRequestClears() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let castPresentation = BattleCastPresentationState()
        castPresentation.stuckResetDelayOverride = 0.02
        castPresentation.append(
            CardActivationRequest(
                artworkName: nil,
                center: .zero,
                size: .zero,
                rotation: 0,
                verticalTilt: 0,
                scale: 1,
                keywords: [.physical]
            )
        )
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastActive: { castPresentation.request != nil },
            isManualInteractionActive: { false },
            playCard: { card in
                let resolution = session.playCard(cardID: card.id)
                guard resolution.didCommit else { return false }
                playedCardIDs.append(card.id)
                session.isAutoBattleEnabled = false
                return true
            }
        )

        #expect(castPresentation.request == nil)
        #expect(!playedCardIDs.isEmpty)
    }

    @Test func autoBattleReturnsWhenBattleIsMissing() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        session.endBattle()
        session.isAutoBattleEnabled = true

        await session.driveAutoBattle(
            isCardCastActive: { false },
            isManualInteractionActive: { false },
            playCard: { _ in false }
        )
    }

    @Test func autoBattleResumesAfterCinematicClears() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: CombatantFixtures.combatant(
                id: "knight",
                role: .hero,
                abilities: [.slash, .fireball, .avatarOfJustice]
            ),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                actionIntervalTurns: 100,
                abilities: []
            )
        )
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.avatarOfJustice.id,
                on: session,
                at: now
            )
        )
        _ = session.playCard(cardID: ultimate.id, at: now)
        #expect(session.spectacle.activeCinematic != nil)

        var playedAfterCinematic = 0
        session.isAutoBattleEnabled = true
        let driver = Task { @MainActor in
            await session.driveAutoBattle(
                isCardCastActive: { false },
                isManualInteractionActive: { false },
                playCard: { card in
                    let resolution = session.playCard(cardID: card.id)
                    guard resolution.didCommit else { return false }
                    playedAfterCinematic += 1
                    session.isAutoBattleEnabled = false
                    return true
                }
            )
        }

        try await Task.sleep(for: .milliseconds(40))
        #expect(playedAfterCinematic == 0)

        session.completeCinematicCollapse(at: now.addingTimeInterval(1))
        #expect(try await BattleSessionTestSupport.waitUntil { playedAfterCinematic > 0 })
        _ = await driver.result
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
