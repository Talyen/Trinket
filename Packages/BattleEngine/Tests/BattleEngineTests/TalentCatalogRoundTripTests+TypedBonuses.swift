import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [("knight_holy_t2_1", 3), ("pixie_holy_t3_2", 1)])
    func `next attack holy bonus keeps its damage type`(talent: String, bonus: Int) {
        var resistance = CombatModifierProfile.zero
        resistance.merge([.damageTakenPercent(.physical, 1)])
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: CombatantTalentCatalog.profile(for: [talent]),
            enemyModifiers: resistance,
        )
        battle.appliesFightPacing = false
        _ = CombatTriggerEngine.afterHolyDamageDealt(to: battle.enemy, source: battle.hero, in: &battle)
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
                options: DamageOperation.attack(
                    tier: .skill,
                    scaling: .statsAndItems,
                    accuracy: .unavoidable,
                    abilityCriticalChanceBonus: -1,
                ),
            ))
            #expect(battle.roster.enemy.currentHealth == 200 - bonus)
            #expect(battle.roster.hero.talents.pending.nextAttackHolyBonus == 0)
        }
    }

    @Test(arguments: [BattleParticipant.hero, .companion], [false, true])
    func `supernal glow adds holy damage to physical basics`(owner: BattleParticipant, basic: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_holy_t3_1"]),
        )
        battle.appliesFightPacing = false
        _ = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.roster[owner].id,
            options: DamageOperation.attack(
                tier: basic ? .basic : .skill,
                scaling: .statsAndItems,
                accuracy: .unavoidable,
                abilityCriticalChanceBonus: -1,
            ),
        ))
        #expect(battle.roster.enemy.currentHealth == (basic ? 188 : 190))
    }

    @Test(arguments: [Ability.pixieDust, .stargaze])
    func `frost guard adds freeze to every empowered element`(original: Ability) {
        var battle = heroTalentBattle("mana_moth_freeze_t1_2")
        battle.roster.hero.currentMana = 3
        var ability = original
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        let freeze = ability.damageComponents.filter { $0.keyword == .freeze }.reduce(0) { $0 + $1.amount }
        #expect(freeze == (original.id == Ability.pixieDust.id ? 1 : 3))
        #expect(battle.roster.hero.currentMana == 0)
    }
}
