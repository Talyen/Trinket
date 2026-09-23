import BattleEngine
import Testing
import TrinketContent
@testable import BattleBalanceTools

struct BalanceTalentContrastTests {
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
