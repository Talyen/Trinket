import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport
@testable import BattleEngine
@testable import Trinket

@MainActor
enum BattleSessionTestSupport {
    static func makeConfiguredSession(
        rngSeed: UInt64 = 0,
        hero: Combatant? = nil,
        pet: Combatant? = nil,
        enemy: Combatant? = nil
    ) throws -> BattleSession {
        let resolvedHero = hero ?? CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let resolvedPet = pet ?? CombatantFixtures.combatant(
            id: "pet",
            role: .pet,
            actionIntervalTicks: 100,
            abilities: []
        )
        let resolvedEnemy = enemy ?? CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        let session = BattleSession()
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: rngSeed,
            hero: resolvedHero,
            pet: resolvedPet,
            enemy: resolvedEnemy
        )
        return session
    }

    /// Plays playable cards, then ends the turn, until the battle resolves or the cap is hit.
    @discardableResult
    static func driveUntilOutcome(
        _ session: BattleSession,
        at date: Date = .now,
        journey: JourneyProgressState = .initial,
        homestead: PlayerHomesteadState = .freshStart,
        maxActions: Int = 200
    ) -> Int? {
        var earnedGold: Int?
        var actions = 0
        while session.outcome == nil, actions < maxActions {
            actions += 1
            if let card = session.hand.first(where: { session.isCardPlayable($0) }) {
                earnedGold = session.playCard(
                    cardID: card.id,
                    at: date,
                    journey: journey,
                    homestead: homestead
                )
                if earnedGold != nil { break }
                continue
            }
            if session.canEndTurn {
                earnedGold = session.endTurn(at: date, journey: journey, homestead: homestead)
                if earnedGold != nil { break }
                continue
            }
            break
        }
        return earnedGold
    }

    /// Cycles the hand until `abilityID` is playable (does not play it).
    @discardableResult
    static func drawUntilPlayable(
        _ abilityID: String,
        on session: BattleSession,
        at date: Date = .now,
        journey: JourneyProgressState = .initial,
        homestead: PlayerHomesteadState = .freshStart,
        maxActions: Int = 40
    ) -> BattleCard? {
        var actions = 0
        while session.outcome == nil, actions < maxActions {
            actions += 1
            if let card = session.hand.first(where: {
                $0.ability.id == abilityID && session.isCardPlayable($0)
            }) {
                return card
            }
            if let other = session.hand.first(where: { session.isCardPlayable($0) }) {
                _ = session.playCard(
                    cardID: other.id,
                    at: date,
                    journey: journey,
                    homestead: homestead
                )
                continue
            }
            if session.canEndTurn {
                _ = session.endTurn(at: date, journey: journey, homestead: homestead)
                continue
            }
            break
        }
        return nil
    }

    /// Cycles the hand until `abilityID` is playable, then plays that card.
    @discardableResult
    static func playAbility(
        _ abilityID: String,
        on session: BattleSession,
        at date: Date = .now,
        journey: JourneyProgressState = .initial,
        homestead: PlayerHomesteadState = .freshStart,
        maxActions: Int = 40
    ) -> Int? {
        guard let card = drawUntilPlayable(
            abilityID,
            on: session,
            at: date,
            journey: journey,
            homestead: homestead,
            maxActions: maxActions
        ) else { return nil }
        return session.playCard(
            cardID: card.id,
            at: date,
            journey: journey,
            homestead: homestead
        )
    }
}
