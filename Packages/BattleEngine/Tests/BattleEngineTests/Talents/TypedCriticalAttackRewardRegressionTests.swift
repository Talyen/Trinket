import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct TypedCriticalAttackRewardRegressionTests {
    @Test(
        arguments: ["rogue_poison_t2_1", "rogue_gold_t2_1", "warlock_burn_t4_1", "mana_moth_burn_t1_2", "phoenix_burn_t4_1"],
        [false, true],
    )
    func `typed Critical Hit rewards apply once to cards and Knights Answer`(talent: String, counterattack: Bool) throws {
        let fixtures = UniqueCollectionTests()
        let owner: BattleParticipant = talent.hasPrefix("mana_moth") || talent.hasPrefix("phoenix") ? .companion : .hero
        let keyword: Keyword = talent == "rogue_poison_t2_1" ? .poison : talent == "rogue_gold_t2_1" ? .stun : .burn
        let basic = Ability(
            id: "typed-critical-basic",
            name: "Typed Critical Basic",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: keyword), DamageComponent(1, keyword: keyword)],
            guaranteedCriticalIfEnemyBuffed: true,
        )
        let profile = CombatantTalentCatalog.profile(for: [talent])
        var battle = try fixtures.battle(
            counterattack ? ["the_knights_answer"] : [], owner: owner, extra: profile,
            heroBasic: basic, companionBasic: basic,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash, .slash])
        let actor = battle.roster[owner].combatant
        DefensePoolEngine.set(100, on: battle.enemy, in: &battle)
        let events: [ActionEvent]
        if counterattack {
            fixtures.block(10, owner: owner, in: &battle)
            events = fixtures.enemyHit(1, target: owner, in: &battle).events
        } else {
            events = try fixtures.play(basic, owner: owner, in: &battle)
        }
        #expect(events.count { $0.kind == .abilityDamage && $0.keyword == keyword && $0.isCritical } == 2)
        switch talent {
        case "rogue_poison_t2_1":
            #expect(battle.roster.runtime(for: actor)?.talents.pending.guaranteedBleedCritical == true)
            let bleed = Ability(
                id: "bleed-followup",
                name: "Bleed Followup",
                tier: .basic,
                directDamage: 1,
                damageKeyword: .bleed,
                criticalChanceBonus: -1,
            )
            let followup = try fixtures.play(bleed, owner: owner, in: &battle)
            #expect(followup.contains { $0.kind == .abilityDamage && $0.keyword == .bleed && $0.isCritical })
            #expect(battle.roster.runtime(for: actor)?.talents.pending.guaranteedBleedCritical == false)
        case "rogue_gold_t2_1":
            #expect(events.filter { $0.abilityName == "Cutpurse Cut" && $0.keyword == .gold }.reduce(0) { $0 + $1.amount } == 5)
        case "warlock_burn_t4_1":
            #expect(events.filter { $0.abilityName == "Ashen Arsenal" && $0.effectKind == .cardsDrawn }.reduce(0) { $0 + $1.amount } == 1)
        default:
            let expected = talent == "mana_moth_burn_t1_2" ? 2 : 3
            #expect(battle.roster[owner].currentMana == expected)
            #expect(events.count { $0.effectKind == .resourceGain && $0.keyword == .mana } == 1)
        }
    }
}
