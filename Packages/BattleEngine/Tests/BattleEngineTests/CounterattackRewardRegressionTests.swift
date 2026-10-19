import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CounterattackRewardRegressionTests {
    @Test func `Temper Cycle readies Bleed damage after a Burn Basic counterattack`() {
        var battle = makeBattle(talents: ["warlock_burn_t4_2"])

        _ = counter(.fireArrow, in: &battle)
        #expect(battle.health(of: battle.enemy) == 97)
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus?.value == 1)

        _ = counter(.rendingSlash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 94)
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus == nil)
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

    @Test(arguments: [false, true], [false, true])
    func `Bloodfire and legacy conditional Physical bonuses strengthen counters and repeats without extra hits`(
        bloodfire: Bool,
        damageRepeat: Bool,
    ) {
        var battle = makeBattle(talents: bloodfire ? ["warlock_burn_t1_1"] : []) {
            if !bloodfire {
                $0.triggers.physicalAttackDamageVsBurningOrFrozenFlat = 1
            }
        }
        battle.insertEffect(bloodfire ? .bleed(1) : .burn(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 1)
        let events = counter(bloodfire ? .fireArrow : .slash, origin: damageRepeat ? .criticalRepeat : .counterattack, in: &battle)
        #expect(battle.health(of: battle.enemy) == 96)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.keyword) == [bloodfire ? .burn : .physical])
        #expect(CombatTriggerEngine.totalPotency(of: .bleed, on: battle.enemy, in: battle) == (bloodfire ? 1 : 0))
    }

    @Test(arguments: [UInt64(7), 23])
    func `Prismatic Edge adds elemental damage to a Basic counterattack`(seed: UInt64) {
        var battle = makeBattle(talents: ["wildcard_physical_t1_1"])
        battle.rng = SeededRandomNumberGenerator(seed: seed)

        let events = counter(.slash, in: &battle)

        #expect(battle.health(of: battle.enemy) == 94)
        let proc = events.filter { $0.kind == .abilityDamage && $0.abilityName == "Prismatic Edge" }
        #expect(proc.map(\.amount) == [3])
        #expect(proc.first?.keyword == (seed == 7 ? .freeze : .burn))
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
        battle.insertEffect(.nextStrikeCritical, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
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
        return BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
    }

    private func counter(
        _ ability: Ability, origin: DamageOperation.AttackOrigin = .counterattack, in battle: inout BattleState,
    ) -> [ActionEvent] {
        battle.recordingEvents { battle in
            await BattleTurnEngine.performAction(
                ability: ability, actor: battle.hero, abilityTarget: battle.enemy,
                origin: origin, context: &battle,
            )
        }
    }
}
