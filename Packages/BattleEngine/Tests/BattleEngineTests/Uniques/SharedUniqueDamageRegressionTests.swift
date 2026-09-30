import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct SharedUniqueDamageRegressionTests {
    @Test(arguments: [Keyword.holy, .burn, .bleed], [BattleParticipant.hero, .companion])
    func `shared damage includes both keyword percentages and universal bonuses once`(
        keyword: Keyword,
        owner: BattleParticipant,
    ) throws {
        let sharedKeyword: Keyword = switch keyword {
        case .holy: .physical
        case .burn: .bleed
        default: .burn
        }
        let unique = keyword == .holy ? "oathkeeper" : "bloodember_pendant"
        let profile = CombatModifierProfile(
            damageDealtPercents: [keyword: 0.1, sharedKeyword: 0.2],
            companionDamageDealtPercent: 0.3,
        )
        let fixtures = UniqueCollectionTests()
        var context = try fixtures.battle([unique], owner: owner, extra: profile)

        try fixtures.play(fixtures.attack(keyword, amount: 100), owner: owner, in: &context)

        #expect(context.roster.enemy.currentHealth == 1840)

        var ordinary = try fixtures.battle([], owner: owner, extra: profile)
        try fixtures.play(fixtures.attack(keyword, amount: 100), owner: owner, in: &ordinary)
        #expect(ordinary.roster.enemy.currentHealth == 1860)
    }
}
