import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import BattleEngine
@testable import Trinket

@MainActor
enum BattleSessionTestSupport {
    static func makeConfiguredSession(
        rngSeed: UInt64 = 0,
        hero: Combatant? = nil,
        pet: Combatant? = nil,
        enemy: Combatant? = nil
    ) -> BattleSession {
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
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            rngSeed: rngSeed,
            hero: resolvedHero,
            pet: resolvedPet,
            enemy: resolvedEnemy
        )
        return session
    }
}
