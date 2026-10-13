import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CounterattackRewardRegressionTests {
    @Test func `Temper Cycle readies Bleed damage after a Burn Basic counterattack`() {
        var battle = makeBattle(talents: ["warlock_burn_t4_2"])

        _ = counter(.fireArrow, in: &battle)
        #expect(battle.health(of: battle.enemy) == 97)
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus == 1)

        _ = counter(.rendingSlash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 94)
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus == 0)
        _ = counter(.rendingSlash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 92)
    }

    @Test func `Consolation Prize grants one card for a fully blocked Basic counterattack`() {
        var battle = makeBattle(talents: ["wildcard_gold_t1_1"])
        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)

        let events = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.hand.totalCount == 1)
        #expect(events.contains { $0.abilityName == "Consolation Prize" && $0.effectKind == .cardsDrawn })

        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)
        _ = counter(.slash, in: &battle)
        #expect(battle.hand.totalCount == 1)
        #expect(battle.gold == 0)
    }

    @Test func `Feigned Miss doubles only the next Physical attack after a blocked Basic counterattack`() {
        var battle = makeBattle(talents: ["wildcard_physical_t3_2"])
        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)

        _ = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.roster.hero.talents.pending.doubleNextPhysicalAttack?.value == true)

        _ = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 94)
        #expect(battle.roster.hero.talents.pending.doubleNextPhysicalAttack == nil)
        _ = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 91)
    }

    @Test(arguments: [false, true])
    func `Supernova can double a Burn Basic counterattack`(damageRepeat: Bool) {
        var battle = makeBattle(talents: ["wizard_burn_t3_1"]) { $0.triggers.burnAttackDoubleChancePercent = 1 }

        _ = counter(.fireArrow, origin: damageRepeat ? .criticalRepeat : .counterattack, in: &battle)

        #expect(battle.health(of: battle.enemy) == (damageRepeat ? 97 : 94))
    }

    @Test(arguments: [false, true])
    func `Bloodfire adds Bleed to a Burn Basic counterattack`(damageRepeat: Bool) {
        var battle = makeBattle(talents: ["warlock_burn_t1_1"]) { $0.triggers.burnAttackBleedChancePercent = 1 }

        _ = counter(.fireArrow, origin: damageRepeat ? .criticalRepeat : .counterattack, in: &battle)

        #expect(battle.health(of: battle.enemy) == (damageRepeat ? 97 : 93))
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.isBleed } == !damageRepeat)
    }

    @Test(arguments: [false, true])
    func `Prismatic Edge adds elemental damage to a Physical Basic counterattack`(damageRepeat: Bool) {
        var battle = makeBattle(talents: ["wildcard_physical_t1_1"]) { $0.triggers.physicalElementChancePercent = 1 }

        _ = counter(.slash, origin: damageRepeat ? .criticalRepeat : .counterattack, in: &battle)

        #expect(battle.health(of: battle.enemy) == (damageRepeat ? 97 : 94))
    }

    @Test func `Hallowguard grants Block after a Holy Basic counterattack but not raw retaliation`() {
        var battle = makeBattle(talents: []) { $0.triggers.holyAttackBlockIfNone = 3 }

        _ = battle.resolveTestDamage(3, keyword: .holy, options: .reaction())
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 0)
        _ = counter(.smite, in: &battle)
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 3)
    }

    @Test(arguments: [0, 2], [false, true])
    func `Light Fingers steals Gold on a Critical Basic counterattack`(theftBonus: Int, fullyBlocked: Bool) {
        var battle = makeBattle(talents: ["rogue_gold_t1_1"]) { $0.triggers.goldStealFlatBonus = theftBonus }
        battle.appendEffect(.nextStrikeCritical, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        if fullyBlocked {
            DefensePoolEngine.set(100, on: battle.enemy, in: &battle)
        }

        _ = counter(.slash, in: &battle)

        #expect(battle.health(of: battle.enemy) == (fullyBlocked ? 100 : 94))
        #expect(battle.gold == 1 + theftBonus)
        _ = counter(.slash, in: &battle)
        #expect(battle.gold == 1 + theftBonus)
    }

    private func makeBattle(
        talents: Set<String>, configure: (inout CombatModifierProfile) -> Void = { _ in },
    ) -> BattleState {
        var profile = CombatantTalentCatalog.profile(for: talents)
        profile.triggers.criticalChanceBonus = -1
        configure(&profile)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    private func counter(
        _ ability: Ability, origin: DamageOperation.AttackOrigin = .counterattack, in battle: inout BattleState,
    ) -> [ActionEvent] {
        BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy,
            origin: origin, context: &battle,
        )
    }
}
