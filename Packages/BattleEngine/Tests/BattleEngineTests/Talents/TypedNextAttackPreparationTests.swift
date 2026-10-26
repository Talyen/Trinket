import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct TypedNextAttackPreparationTests {
    @Test(arguments: [0, 5])
    func `Bounty Blade reserves the strongest theft bonus beyond the creating card repeat`(existingBonus: Int) throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: ["rogue_gold_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = try fixtures.battle([], extra: profile)
        readyRepeat(in: &battle)
        if existingBonus > 0 {
            battle.roster.hero.talents.pending.nextPhysicalDamageBonus = PreparedTalentBonus(value: existingBonus)
        }
        // Theft precedes damage so rearming must exclude this card even when the old value wins.
        let ability = existingBonus == 0 ? Ability.steal : Ability(
            id: "theft-before-hit", name: "Theft Before Hit", tier: .basic, stealsGold: true,
            operations: [.effect(TargetedEffect(.resourceGain(.gold, 1))), .damage(DamageComponent(3, keyword: .physical))],
        )

        let events = try fixtures.play(ability, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == ability.id }
        #expect(hits.map(\.amount) == [3, 3])
        #expect(battle.gold == 2)
        let bonus = max(3, existingBonus)
        #expect(battle.roster.hero.talents.pending.nextPhysicalDamageBonus?.value == bonus)

        let next = try fixtures.play(.slash, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id }?.amount == 3 + bonus)
        #expect(battle.roster.hero.talents.pending.nextPhysicalDamageBonus == nil)
    }

    @Test func `Bloodkindling reserves shared Bleed damage beyond the creating Burn card repeat`() throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: ["warlock_burn_t4_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = try fixtures.battle(["bloodember_pendant"], extra: profile)
        readyRepeat(in: &battle)

        let events = try fixtures.play(.fireArrow, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.fireArrow.id }
        #expect(hits.map(\.amount) == [3, 3])
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus?.value == 1)

        let next = try fixtures.play(.rendingSlash, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage && $0.abilityID == Ability.rendingSlash.id }?.amount == 3)
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus == nil)
    }

    @Test(arguments: ["bear_physical_t1_2", "risen_skeleton_physical_t1_2"])
    func `Block break reserves its physical bonus beyond the creating card repeat`(talentID: String) throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        profile.triggers.criticalChanceBonus = -1
        var battle = try fixtures.battle([], owner: .companion, extra: profile)
        battle.insertEffect(.playNextCardTwice, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        fixtures.block(1, owner: .companion, in: &battle)

        let events = try fixtures.play(.slash, owner: .companion, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id && $0.targetID == battle.enemy.id }
        #expect(hits.map(\.amount) == [3, 3])
        let bonus = talentID == "bear_physical_t1_2" ? 2 : 3
        #expect(battle.roster.companion.talents.pending.nextPhysicalDamageBonus?.value == bonus)

        let next = try fixtures.play(.slash, owner: .companion, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id }?.amount == 3 + bonus)
        #expect(battle.roster.companion.talents.pending.nextPhysicalDamageBonus == nil)
    }

    @Test func `Noxious Reaction reserves its Critical Hit beyond the creating multi hit card repeat`() throws {
        let fixtures = UniqueCollectionTests()
        var battle = try fixtures.battle([], extra: CombatantTalentCatalog.profile(for: ["rogue_poison_t2_1"]))
        readyRepeat(in: &battle)
        // Only the first Poison hit crits, so a later critical cannot recreate a consumed preparation.
        battle.rng = SeededRandomNumberGenerator(seed: CombatantFixtures.deterministicBattleSeedVariant(15))
        let ability = Ability(
            id: "split-leech", name: "Split Leech", tier: .ultimate,
            damageComponents: [DamageComponent(2, keyword: .bleed, hasLeech: true), DamageComponent(1, keyword: .poison)],
        )

        let events = try fixtures.play(ability, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == ability.id }
        #expect(hits.map(\.keyword) == [.bleed, .poison, .bleed, .poison])
        #expect(hits.map(\.isCritical) == [false, true, false, false])
        #expect(battle.roster.hero.talents.pending.guaranteedBleedCritical?.value == true)

        let next = try fixtures.play(.rendingSlash, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage && $0.abilityID == Ability.rendingSlash.id }?.isCritical == true)
        #expect(battle.roster.hero.talents.pending.guaranteedBleedCritical == nil)
    }

    private func readyRepeat(in battle: inout BattleState) {
        // The supported playNextCardTwice effect repeats the authored ability within one card frame.
        battle.insertEffect(.playNextCardTwice, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
    }
}
