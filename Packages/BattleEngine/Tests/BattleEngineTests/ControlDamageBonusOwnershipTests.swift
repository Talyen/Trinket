import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ControlDamageBonusOwnershipTests {
    @Test(arguments: ["shatter", "dazed", "knight_stun_t1_1"], [false, true])
    func `control damage bonuses belong to the attacker`(powerID: String, companionOwnsPower: Bool) throws {
        let profile: CombatModifierProfile
        let bonus: Int
        if powerID == "knight_stun_t1_1" {
            profile = CombatantTalentCatalog.profile(for: [powerID])
            bonus = 3
        } else {
            let affix = try #require(GameContent.itemAffixDefinition(matching: powerID))
            var affixProfile = CombatModifierProfile.zero
            affix.basic.triggers.apply(to: &affixProfile, abilityName: affix.title)
            profile = affixProfile
            bonus = 2
        }
        let control: Keyword = powerID == "shatter" ? .freeze : .stun
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            enemyEffects: [ActiveEffect(id: 1, effect: .controlMeter(control, 100, 100), remainingTurns: 1)],
            heroModifiers: companionOwnsPower ? .zero : profile,
            companionModifiers: companionOwnsPower ? profile : .zero,
        )
        battle.appliesFightPacing = false
        let owner = companionOwnsPower ? battle.companion : battle.hero
        let partner = companionOwnsPower ? battle.hero : battle.companion
        let attack = DamageOperation.attack(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)

        let ownerDamage = battle.resolveDamage(DamageRequest(
            amount: 5, target: battle.enemy, keyword: .physical,
            sourceActorID: owner.id, options: attack,
        ))
        let partnerDamage = battle.resolveDamage(DamageRequest(
            amount: 5, target: battle.enemy, keyword: .physical,
            sourceActorID: partner.id, options: attack,
        ))

        #expect(ownerDamage.healthLost == 5 + bonus)
        #expect(partnerDamage.healthLost == 5)
    }
}
