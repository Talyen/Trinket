import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import TrinketBattleFeature

@MainActor
struct CombatSFXMapperTests {
    // swiftlint:disable function_body_length - mapper branches stay one fast test
    @Test func `semantic feedback mappings cover typed fallback and silent cases`() {
        for keyword: Keyword in [.physical, .holy, .poison, .bleed, .leech] {
            let item = feedbackItem(feedbackClass: .directDamage, keyword: keyword, label: .amount(-10))
            #expect(CombatSFXMapper.clipID(for: item) == SFXID.hit)
        }
        let item = feedbackItem(
            feedbackClass: .critical,
            keyword: .physical,
            label: .amount(-10),
        )
        #expect(CombatSFXMapper.clipID(for: item) == SFXID.hit)
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .directDamage, keyword: .burn, label: .amount(-8)),
            ) == SFXID.hitBurn,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .directDamage, keyword: .freeze, label: .amount(-8)),
            ) == SFXID.hitFreeze,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .heal, keyword: .health, label: .amount(12)),
            ) == SFXID.heal,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .buff,
                    keyword: .poison,
                    label: .word(.cleanse(.poison)),
                ),
            ) == SFXID.heal,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .buff,
                    keyword: .block,
                    label: .word(.purge(.block)),
                ),
            ) == SFXID.purge,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .buff, keyword: .block, label: .amount(20)),
            ) == SFXID.block,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .buff, keyword: .block, label: .amount(10)),
            ) == SFXID.block,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .buff,
                    keyword: .physical,
                    label: .word(.status(.marked)),
                    visualRole: .negativeStatus,
                ),
            ) == nil,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .control,
                    keyword: .freeze,
                    label: .word(.triggered(.freeze)),
                ),
            ) == SFXID.controlFreeze,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .control,
                    keyword: .stun,
                    label: .word(.triggered(.stun)),
                ),
            ) == SFXID.controlStun,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .dodge, keyword: .dodge, label: .word(.dodge)),
            ) == nil,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .block, keyword: .block, label: .amount(-5)),
            ) == nil,
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .deathsDoor,
                    keyword: .deathsDoor,
                    label: .word(.plain(.deathsDoor)),
                ),
            ) == SFXID.deathsDoor,
        )
    }

    // swiftlint:enable function_body_length

    @Test func `unique clip I ds dedupes and prefer typed hits across targets`() {
        #expect(
            CombatSFXMapper.uniqueClipIDs(for: [
                feedbackItem(id: 1, feedbackClass: .buff, keyword: .stun, label: .word(.cleanse(.stun))),
                feedbackItem(id: 2, feedbackClass: .heal, keyword: .health, label: .amount(1)),
                feedbackItem(id: 3, feedbackClass: .buff, keyword: .block, label: .amount(4)),
                feedbackItem(id: 4, feedbackClass: .buff, keyword: .block, label: .amount(22)),
            ]) == [SFXID.heal, SFXID.block],
        )
        #expect(
            CombatSFXMapper.uniqueClipIDs(for: [
                feedbackItem(id: 1, feedbackClass: .directDamage, keyword: .physical, label: .amount(-6)),
                feedbackItem(id: 2, feedbackClass: .dot, keyword: .burn, label: .amount(-2)),
            ]) == [SFXID.hitBurn],
        )
        #expect(
            CombatSFXMapper.uniqueClipIDs(for: [
                feedbackItem(id: 1, feedbackClass: .dot, keyword: .burn, label: .amount(-2)),
                feedbackItem(id: 2, feedbackClass: .dot, keyword: .poison, label: .amount(-1)),
            ]) == [SFXID.hitBurn, SFXID.hit],
        )
        #expect(
            CombatSFXMapper.uniqueClipIDs(for: [
                feedbackItem(id: 1, targetID: "enemy", feedbackClass: .dot, keyword: .burn, label: .amount(-2)),
                feedbackItem(id: 2, targetID: "hero", feedbackClass: .dot, keyword: .burn, label: .amount(-2)),
                feedbackItem(id: 3, targetID: "companion", feedbackClass: .dot, keyword: .burn, label: .amount(-1)),
                feedbackItem(id: 4, targetID: "enemy", feedbackClass: .dot, keyword: .poison, label: .amount(-3)),
            ]) == [SFXID.hitBurn, SFXID.hit],
        )
    }

    private func feedbackItem(
        id: Int = 1,
        targetID: String = "target",
        feedbackClass: CombatFeedbackClass,
        keyword: Keyword,
        label: CombatFeedbackChipLabel,
        visualRole: CombatFeedbackVisualRole = .keyword,
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: id,
            sourceEventIDs: [id],
            actionGroupID: id,
            presentationIndex: 0,
            groupResultCount: 1,
            presentationRole: .headline,
            targetID: targetID,
            feedbackClass: feedbackClass,
            keyword: keyword,
            visualRole: visualRole,
            label: label,
            availableAt: .now,
            expiresAt: .now.addingTimeInterval(BattleMotion.chipDisplayDuration),
            reactionKind: .none,
        )
    }
}
