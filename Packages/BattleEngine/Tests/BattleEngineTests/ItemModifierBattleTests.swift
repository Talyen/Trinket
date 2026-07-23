import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct ItemModifierBattleTests {
    @Test(arguments: [
        (affixID: "keen", abilityID: "slash"),
        (affixID: "serrated", abilityID: "fangs")
    ])
    func equippedDamageAffixIncreasesCardDamage(affixID: String, abilityID: String) throws {
        let affix = try #require(GameContent.itemAffixDefinitions.first { $0.id == affixID })
        let ability = try #require(GameContent.ability(id: abilityID))
        let modifiers = CombatModifierProfile(modifiers: affix.basic.modifiers)

        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [ability]
        )
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 20, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: []
        )

        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: modifiers
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == (abilityID == "slash" ? 3 : 2))
    }

    @Test func equippedMaximumHealthAffixIncreasesStartingHealth() throws {
        let hale = try #require(GameContent.itemAffixDefinitions.first { $0.id == "hale" })
        let modifiers = CombatModifierProfile(modifiers: hale.basic.modifiers)

        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 0)
        )
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 10, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 10,
            abilities: []
        )

        let battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: modifiers
        )

        try #expect(battle.health(of: battle.hero) == 16)
    }
}
