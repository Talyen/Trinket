import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CompanionBasicBonusRegressionTests {
    @Test(arguments: [Keyword.bleed, .stun, .physical], [false, true])
    func `companion attack talents apply to Knights Answer and retain their turn allowances`(
        keyword: Keyword,
        answersBlockedHit: Bool,
    ) throws {
        let basic: Ability = switch keyword {
        case .bleed: .fangs
        case .stun: .shieldBash
        default: .slash
        }
        let talentID = switch keyword {
        case .bleed: "panther_bleed_t1_1"
        case .stun: "bear_stun_t1_1"
        default: "bear_physical_t4_1"
        }
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        profile.triggers.criticalChanceBonus = -1
        let fixtures = UniqueCollectionTests()
        var context = try fixtures.battle(
            answersBlockedHit ? ["the_knights_answer"] : [],
            owner: .companion,
            extra: profile,
            companionBasic: basic,
        )
        fixtures.block(answersBlockedHit ? 11 : 10, owner: .companion, in: &context)

        if answersBlockedHit {
            let hit = fixtures.enemyHit(1, target: .companion, in: &context)
            #expect(hit.events.contains { $0.kind == .ability && $0.abilityID == basic.id })
        } else {
            try fixtures.play(basic, owner: .companion, in: &context)
        }

        let firstDamage = keyword == .bleed ? 2 : 8
        #expect(context.roster.enemy.currentHealth == 2000 - firstDamage)

        let beforeNextAttack = context.roster.enemy.currentHealth
        try fixtures.play(basic, owner: .companion, in: &context)

        let nextDamage = switch keyword {
        case .bleed: 2
        case .stun: 6
        default: 3
        }
        #expect(context.roster.enemy.currentHealth == beforeNextAttack - nextDamage)
    }
}
