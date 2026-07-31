import BattleEngine
import Testing
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
@testable import TrinketBattleFeature

@MainActor
struct BattleRunConfigurationTests {
    @Test func storesOnlySimulationInputsAndBakedPartyBuilds() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let heroProgression = CombatantProgression(level: 4, currentXP: 12, requiredXP: 275)
        let companionProgression = CombatantProgression(level: 2, currentXP: 3, requiredXP: 155)
        let configuration = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("journey|audit-stage"),
            rngSeed: 42,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 6,
            heroProgression: heroProgression,
            companionProgression: companionProgression,
            heroEquipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.weapon: "shortsword-basic"]),
            companionEquipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.armor: "leather_armor-basic"]),
            heroModifiers: CombatModifierProfile(maximumHealthBonus: 5),
            companionModifiers: CombatModifierProfile(damageDealtBonus: [.physical: 2]),
            enemyModifiers: CombatModifierProfile(maximumHealthBonus: 3)
        )

        #expect(configuration.runKey == BattleRunKey("journey|audit-stage"))
        #expect(configuration.rngSeed == 42)
        #expect(configuration.hero.combatant == hero)
        #expect(configuration.hero.progression == heroProgression)
        #expect(configuration.hero.equipmentLoadout.itemID(for: .weapon) == "shortsword-basic")
        #expect(configuration.companion.progression == companionProgression)
        #expect(configuration.enemy == enemy)
        #expect(configuration.enemyEncounterLevel == 6)
        #expect(configuration.enemyModifiers.maximumHealthBonus == 3)
    }

    @Test func partyMemberLookupUsesBakedCombatantIDs() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let configuration = BattleRunConfigurationTestSupport.make(
            hero: hero,
            companion: companion
        )

        #expect(configuration.partyMember(for: hero.id)?.combatant == hero)
        #expect(configuration.partyMember(for: companion.id)?.combatant == companion)
        #expect(configuration.partyMember(for: "unknown") == nil)
    }
}
