import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `sacrificial guard does not weaken the redirected hit twice`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t3_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        battle.appendEffect(.damageReductionFlat(2, 2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)

        _ = battle.resolveDamage(DamageRequest(
            amount: 6, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id, options: .reaction(),
        ))

        #expect(battle.roster.hero.currentHealth == 1)
        #expect(battle.roster.companion.currentHealth == 16)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 10)
    }

    @Test(arguments: [
        "knight_stun_t2_1", "bear_stun_t1_1", "bear_stun_t3_2",
        "bear_physical_t3_2", "mana_moth_freeze_t1_1",
    ], [false, true])
    func `attack talents deal advertised damage`(talentID: String, active: Bool) {
        var battle = heroTalentBattle(talentID)
        let skullcracker = talentID == "knight_stun_t2_1"
        let groundSlam = talentID == "bear_stun_t1_1"
        let seismicRoar = talentID == "bear_stun_t3_2"
        let pulverize = talentID == "bear_physical_t3_2"
        let chillingFlutter = talentID == "mana_moth_freeze_t1_1"
        if skullcracker, active {
            seedHeroTalentEffect(.controlMeter(.stun, 20, 20), on: .enemy, in: &battle)
        }
        if seismicRoar {
            battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = active ? 9 : 10 }
        }
        let keyword: Keyword = !active && (groundSlam || pulverize) ? .holy : .physical
        let bonus = active ? (groundSlam ? 1 : 2) : 0
        for hit in 1 ... 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
                options: DamageOperation.attack(tier: chillingFlutter && active ? .basic : .skill, scaling: .flat, accuracy: .unavoidable),
            ))
            let bonusHits = pulverize ? 1 : hit
            #expect(battle.roster.enemy.currentHealth == 100 - hit - bonus * bonusHits)
        }
        if active, !skullcracker {
            let control: Keyword = chillingFlutter ? .freeze : .stun
            let buildup = pulverize ? 1 : bonus * 2
            #expect(battle.roster.enemy.activeEffects.contains { $0.effect == .controlMeter(control, buildup, 20) })
        }
        if pulverize {
            #expect(battle.roster.enemy.activeEffects.count(where: \.effect.isBleed) == (active ? 1 : 0))
        }
    }
}
