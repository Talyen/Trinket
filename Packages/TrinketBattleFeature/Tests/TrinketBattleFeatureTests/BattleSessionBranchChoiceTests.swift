import Foundation
import Testing
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionBranchChoiceTests {
    private func makeSession(
        heroAbilities: [Ability],
        companionAbilities: [Ability],
        isAutoBattleEnabled: Bool = false
    ) -> (session: BattleSession, card: BattleCard?) {
        let session = BattleSession(
            openingHandDrawStagger: 0,
            presentationEnvironment: .silent
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: heroAbilities)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, abilities: companionAbilities)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 200, abilities: [])
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            hero: hero,
            companion: companion,
            enemy: enemy
        )
        _ = session.activate(configuration)
        session.installPresentationContext(presentation)
        // `activate` resets auto-battle from preferences, so enable it last.
        if isAutoBattleEnabled {
            session.isAutoBattleEnabled = true
        }
        let card = session.hand.first { $0.owner == .hero }
        return (session, card)
    }

    private func branchRequest(for card: BattleCard) -> CardActivationRequest {
        CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: CGPoint(x: 100, y: 500),
            size: CGSize(width: 96, height: 134),
            rotation: 0,
            verticalTilt: 0,
            scale: 1,
            perspective: TrinketMotion.Battle.cardPerspective,
            keywords: card.ability.keywords
        )
    }

    @Test func branchableCardPresentsChoiceOverlay() throws {
        let (session, handCard) = makeSession(
            heroAbilities: [.maul],
            companionAbilities: [.bash]
        )
        let card = try #require(handCard)

        #expect(session.shouldPresentBranchChoice(for: card))
        session.presentBranchChoice(for: card, activation: branchRequest(for: card))

        let pending = try #require(session.pendingBranchChoice)
        #expect(pending.cardID == card.id)
        #expect(pending.choices.count == 2)
        #expect(!session.canEndTurn)
    }

    @Test func plainCardSkipsChoiceOverlay() {
        let (session, card) = makeSession(
            heroAbilities: [.slash],
            companionAbilities: [.bash]
        )
        guard let card else {
            Issue.record("Expected a hero card in hand")
            return
        }
        #expect(!session.shouldPresentBranchChoice(for: card))
        #expect(session.pendingBranchChoice == nil)
        #expect(session.canEndTurn)
    }

    @Test func autoBattleNeverPresentsChoice() {
        let (session, card) = makeSession(
            heroAbilities: [.maul],
            companionAbilities: [.bash],
            isAutoBattleEnabled: true
        )
        guard let card else {
            Issue.record("Expected a hero card in hand")
            return
        }
        #expect(!session.shouldPresentBranchChoice(for: card))
    }

    @Test func dismissingChoiceReopensEndTurn() throws {
        let (session, handCard) = makeSession(
            heroAbilities: [.maul],
            companionAbilities: [.bash]
        )
        let card = try #require(handCard)
        session.presentBranchChoice(for: card, activation: branchRequest(for: card))
        #expect(session.pendingBranchChoice != nil)

        session.dismissBranchChoice()

        #expect(session.pendingBranchChoice == nil)
        #expect(session.canEndTurn)
    }

    @Test func sessionPlayAppliesOnlyTheChosenBranch() throws {
        let bleed = try playChosenMaulBranch(1)
        #expect(bleed.contains { effect in
            guard case .bleed = effect.effect else { return false }
            return true
        })

        let stun = try playChosenMaulBranch(0)
        #expect(stun.allSatisfy { effect in
            guard case .bleed = effect.effect else { return true }
            return false
        })
    }

    /// Plays Maul through the session with `branchIndex` and returns the enemy's
    /// active effects, proving the session passes the pick through to the engine.
    private func playChosenMaulBranch(
        _ branchIndex: Int
    ) throws -> [ActiveEffect] {
        let (session, handCard) = makeSession(
            heroAbilities: [.maul],
            companionAbilities: []
        )
        let card = try #require(handCard)
        session.playCard(cardID: card.id, branchIndex: branchIndex)

        let engineState = try #require(session.engineState)
        return engineState.activeEffects(of: engineState.enemy)
    }
}
