import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketTestSupport
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionAutoBattleTests {
    @Test func autoBattlePlaysCardsInGreedyOrderUntilDisabled() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let expectedCardIDs = try BattleSessionTestSupport.greedyPlaySequence(from: session)
        var playedCardIDs: [Int] = []

        await BattleSessionTestSupport.driveAutoBattleUntilStopped(session: session) { card in
            let resolution = session.playCard(cardID: card.id)
            guard resolution.didCommit else { return false }
            playedCardIDs.append(card.id)
            if playedCardIDs.count == expectedCardIDs.count {
                session.isAutoBattleEnabled = false
            }
            return true
        }

        #expect(playedCardIDs == expectedCardIDs)
    }

    @Test func autoBattleRetriesAfterARejectedPlayInsteadOfStopping() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let expectedCardIDs = try BattleSessionTestSupport.greedyPlaySequence(from: session)
        var playAttempts = 0
        var playedCardIDs: [Int] = []

        await BattleSessionTestSupport.driveAutoBattleUntilStopped(session: session) { card in
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

        #expect(playAttempts > expectedCardIDs.count)
        #expect(playedCardIDs == expectedCardIDs)
    }

    private enum ResumeGate: Sendable {
        case manualInteraction
        case cardCast
    }

    @Test(arguments: [ResumeGate.manualInteraction, .cardCast])
    private func autoBattleResumesAfterGateClears(gate: ResumeGate) async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        var remainingBlocks = 3
        var playedCardIDs: [Int] = []

        let playCard: @MainActor (BattleCard) async -> Bool = { card in
            let resolution = session.playCard(cardID: card.id)
            guard resolution.didCommit else { return false }
            playedCardIDs.append(card.id)
            session.isAutoBattleEnabled = false
            return true
        }

        switch gate {
        case .manualInteraction:
            await BattleSessionTestSupport.driveAutoBattleUntilStopped(
                session: session,
                isManualInteractionActive: {
                    guard remainingBlocks > 0 else { return false }
                    remainingBlocks -= 1
                    return true
                },
                playCard: playCard
            )
        case .cardCast:
            await BattleSessionTestSupport.driveAutoBattleUntilStopped(
                session: session,
                isCardCastActive: {
                    guard remainingBlocks > 0 else { return false }
                    remainingBlocks -= 1
                    return true
                },
                playCard: playCard
            )
        }

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

        #expect(try await BattleSessionTestSupport.waitUntil {
            remainingCastBlocks == 0 && session.overlayAbilityDetail != nil
        })
        #expect(playedCardIDs.isEmpty)

        session.overlayAbilityDetail = nil
        #expect(try await BattleSessionTestSupport.waitUntil { !playedCardIDs.isEmpty })
        _ = await driver.result
    }

    @Test func autoBattleDoesNotPlayDuringSustainedManualInteraction() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        var interacting = true
        var interactionChecks = 0
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        let driver = Task { @MainActor in
            await session.driveAutoBattle(
                isCardCastActive: { false },
                isManualInteractionActive: {
                    interactionChecks += 1
                    return interacting
                },
                playCard: { card in
                    let resolution = session.playCard(cardID: card.id)
                    guard resolution.didCommit else { return false }
                    playedCardIDs.append(card.id)
                    session.isAutoBattleEnabled = false
                    return true
                }
            )
        }

        #expect(try await BattleSessionTestSupport.waitUntil { interactionChecks > 0 })
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

        #expect(session.spectacle.activeCinematic != nil)
        #expect(
            try await BattleSessionTestSupport.waitUntil(timeout: .milliseconds(80)) {
                playedAfterCinematic > 0
            } == false
        )

        session.completeCinematicCollapse(at: now.addingTimeInterval(1))
        #expect(try await BattleSessionTestSupport.waitUntil { playedAfterCinematic > 0 })
        _ = await driver.result
    }

    @Test func autoBattleResetsOffOnNewBattleWhenRememberIsOff() throws {
        let probe = AutoBattleProbe(remember: false, stored: false)
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            presentationEnvironment: autoBattleEnvironment(probe: probe)
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
        let probe = AutoBattleProbe(remember: true, stored: true)
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            presentationEnvironment: autoBattleEnvironment(probe: probe)
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
}

// Concurrency-Safety: `@unchecked Sendable` — test probe is mutated only
private final class AutoBattleProbe: @unchecked Sendable {
    var remember: Bool
    var stored: Bool
    var persistedValues: [Bool] = []

    init(remember: Bool, stored: Bool) {
        self.remember = remember
        self.stored = stored
    }
}

@MainActor
private func autoBattleEnvironment(probe: AutoBattleProbe) -> BattleRuntimeDependencies {
    BattleRuntimeDependencies(
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
}
