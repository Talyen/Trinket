import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct BalanceTalentContrastTests {
    @Test func `paired talent builds preserve the partner and differ only by the focused choice`() throws {
        let wizard = try #require(GameContent.hero(matching: "wizard"))
        let wolf = try #require(GameContent.companion(matching: "wolf"))
        let enemy = try #require(GameContent.enemy(matching: "goblin"))
        let config = BalanceSweepConfig(mode: .talentContrast, tiers: [.lateGame], jobs: 1)
        let context = BalanceContrastContext(config: config, heroes: [wizard], companions: [wolf], enemies: [enemy])
        let focus = try #require(BalanceTalentContrastRunner.siblingFoci(
            heroes: [wizard], companions: [], focusIDs: ["wizard_mana_t1_1"],
        ).first)
        let pair = try #require(BalanceTalentContrastRunner.makePair(
            focus: .sibling(focus), tier: .lateGame, pairIndex: 0, seed: 43, context: context,
        ))
        let entity = Set(pair.withEntity.context.heroTalentIDs)
        let baseline = Set(pair.withBaseline.context.heroTalentIDs)
        let sibling = try #require(focus.siblingID)
        #expect(entity.subtracting(baseline) == [focus.focusID])
        #expect(baseline.subtracting(entity) == [sibling])
        #expect(entity.count > focus.prefix.count + 1)
        #expect(entity.count <= CombatantProgression.at(level: 40).totalTalentPoints)
        #expect(baseline.count == entity.count)
        #expect(pair.withEntity.context.companionTalentIDs == pair.withBaseline.context.companionTalentIDs)
        #expect(!pair.withEntity.context.companionTalentIDs.isEmpty)
        #expect(pair.withEntity.context.heroAffixIDs == pair.withBaseline.context.heroAffixIDs)
    }

    @Test func `early card comparisons share starter gear and legal kits on both sides`() throws {
        let hero = try #require(GameContent.hero(matching: "warlock"))
        let companion = try #require(GameContent.companion(matching: "wolf"))
        let enemy = try #require(GameContent.enemy(matching: "goblin"))
        let context = BalanceContrastContext(
            config: BalanceSweepConfig(), heroes: [hero], companions: [companion], enemies: [enemy],
        )
        let base = BalanceContrastSupport.base(owner: hero, tier: .early, pairIndex: 0, context: context, pairSeed: 43)
        let entity = base.matchup()
        let baseline = base.matchup(ownerLoadout: base.ownerLoadout.selecting(.faustianBargain))
        #expect(entity.context.heroAffixIDs.count == 1)
        #expect(entity.context.companionAffixIDs.count == 1)
        #expect(entity.context.heroAffixIDs == baseline.context.heroAffixIDs)
        #expect(entity.context.companionAffixIDs == baseline.context.companionAffixIDs)
        #expect(!entity.context.heroTalentIDs.isEmpty && !entity.context.companionTalentIDs.isEmpty)
        #expect(entity.context.heroTalentIDs == baseline.context.heroTalentIDs)
        #expect(entity.context.companionTalentIDs == baseline.context.companionTalentIDs)
    }

    @Test func `focused talent contrasts include both requested nodes in one row`() throws {
        let wildcard = try #require(GameContent.heroes.first { $0.id == "wildcard" })
        let focused = BalanceTalentContrastRunner.siblingFoci(
            heroes: [wildcard], companions: [],
            focusIDs: ["wildcard_dodge_t1_2", "wildcard_dodge_t3_2"],
        ).filter { $0.focusID == "wildcard_dodge_t1_2" || $0.focusID == "wildcard_dodge_t3_2" }

        #expect(Set(focused.map(\.focusID)) == ["wildcard_dodge_t1_2", "wildcard_dodge_t3_2"])
        #expect(focused.first { $0.focusID == "wildcard_dodge_t1_2" }?.siblingID == "wildcard_dodge_t3_2")
        #expect(focused.first { $0.focusID == "wildcard_dodge_t3_2" }?.siblingID == "wildcard_dodge_t1_2")
    }

    @Test func `talent contrasts include single node final rows and respect focused identity after moves`() throws {
        let wildcard = try #require(GameContent.heroes.first { $0.id == "wildcard" })
        let owl = try #require(GameContent.companions.first { $0.id == "library_owl" })
        let foci = BalanceTalentContrastRunner.siblingFoci(
            heroes: [wildcard], companions: [owl],
            focusIDs: ["wildcard_dodge_t3_2", "library_owl_holy_t4_1"],
        )
        let introductory = try #require(foci.first { $0.focusID == "wildcard_dodge_t3_2" })
        #expect(introductory.prefix.isEmpty)
        #expect(introductory.siblingID == "wildcard_dodge_t1_2")
        #expect(BalanceTalentContrastRunner.isSiblingLegal(focus: introductory, tier: .early))
        let finalRow = try #require(foci.first { $0.focusID == "library_owl_holy_t4_1" })
        #expect(finalRow.siblingID == nil)
        #expect(finalRow.prefix.count == 6)
        #expect(!BalanceTalentContrastRunner.isSiblingLegal(focus: finalRow, tier: .early))
        #expect(BalanceTalentContrastRunner.isSiblingLegal(focus: finalRow, tier: .middle))
    }
}
