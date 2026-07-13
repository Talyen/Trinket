import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
@testable import Trinket

@MainActor
struct CombatSFXMapperTests {
    // This matrix intentionally keeps all semantic mapper branches in one fast test.
    // swiftlint:disable function_body_length
    @Test func semanticFeedbackMappingsCoverTypedFallbackAndSilentCases() {
        for keyword: Keyword in [.physical, .nature, .holy, .poison, .bleed, .leech] {
            let item = feedbackItem(feedbackClass: .directDamage, keyword: keyword, text: "-10")
            #expect(CombatSFXMapper.clipID(for: item) == SFXID.hit)
        }
        let item = feedbackItem(
            feedbackClass: .critical,
            keyword: .physical,
            text: "-10",
            secondary: "CRIT"
        )
        #expect(CombatSFXMapper.clipID(for: item) == SFXID.hit)
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .directDamage, keyword: .burn, text: "-8")
            ) == SFXID.hitBurn
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .directDamage, keyword: .freeze, text: "-8")
            ) == SFXID.hitFreeze
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .heal, keyword: .health, text: "+12")
            ) == SFXID.heal
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .buff,
                    keyword: .poison,
                    text: "Cleanse Poisoned"
                )
            ) == SFXID.heal
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .buff, keyword: .block, text: "Purge Block")
            ) == SFXID.purge
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .buff, keyword: .block, text: "+20 Block")
            ) == SFXID.block
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .buff, keyword: .armor, text: "+10% Armor")
            ) == SFXID.block
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .control, keyword: .freeze, text: "Frozen!")
            ) == SFXID.controlFreeze
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .control, keyword: .stun, text: "Stunned!")
            ) == SFXID.controlStun
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .dodge, keyword: .dodge, text: "Dodge")
            ) == nil
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .block, keyword: .block, text: "-5")
            ) == nil
        )
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(
                    feedbackClass: .deathsDoor,
                    keyword: .deathsDoor,
                    text: "Death's Door"
                )
            ) == SFXID.deathsDoor
        )
    }

    // swiftlint:enable function_body_length

    @Test func catalogContainsExpectedIDs() {
        let expected = [
            SFXID.uiTap, SFXID.uiConfirm, SFXID.uiCancel, SFXID.uiDecline, SFXID.uiDeny,
            SFXID.uiToggleOn, SFXID.uiToggleOff, SFXID.uiEquip, SFXID.uiUnequip, SFXID.uiBuySell,
            SFXID.abilityDraw,
            SFXID.hit, SFXID.hitBurn, SFXID.hitFreeze,
            SFXID.heal, SFXID.buff, SFXID.block,
            SFXID.controlFreeze, SFXID.controlStun,
            SFXID.purge, SFXID.deathsDoor,
            SFXID.victory, SFXID.defeat, SFXID.mysteryEvent
        ]
        for id in expected {
            #expect(SFXCatalog.clipsByID[id] != nil, "Missing clip \(id)")
        }
        #expect(SFXCatalog.clips.count == expected.count)
        #expect(SFXCatalog.clipsByID["ability_play"] == nil)
    }

    @Test func uniqueClipIDsDedupesIdenticalClips() {
        let items = [
            feedbackItem(id: 1, feedbackClass: .buff, keyword: .stun, text: "Cleanse Stunned"),
            feedbackItem(id: 2, feedbackClass: .heal, keyword: .health, text: "+1 Health"),
            feedbackItem(id: 3, feedbackClass: .buff, keyword: .block, text: "+4 Block"),
            feedbackItem(id: 4, feedbackClass: .buff, keyword: .armor, text: "+22% Armor")
        ]
        #expect(CombatSFXMapper.uniqueClipIDs(for: items) == [SFXID.heal, SFXID.block])
    }

    @Test func uniqueClipIDsPrefersTypedHitOverGenericPhysicalHit() {
        let items = [
            feedbackItem(id: 1, feedbackClass: .directDamage, keyword: .physical, text: "-6"),
            feedbackItem(id: 2, feedbackClass: .dot, keyword: .burn, text: "-2")
        ]
        #expect(CombatSFXMapper.uniqueClipIDs(for: items) == [SFXID.hitBurn])
    }

    @Test func uniqueClipIDsKeepsPoisonHitAlongsideBurn() {
        let items = [
            feedbackItem(id: 1, feedbackClass: .dot, keyword: .burn, text: "-2"),
            feedbackItem(id: 2, feedbackClass: .dot, keyword: .poison, text: "-1")
        ]
        #expect(
            CombatSFXMapper.uniqueClipIDs(for: items) == [SFXID.hitBurn, SFXID.hit]
        )
    }

    @Test func uniqueClipIDsKeepsOneBurnAcrossMultipleTargets() {
        let items = [
            feedbackItem(id: 1, targetID: "enemy", feedbackClass: .dot, keyword: .burn, text: "-2"),
            feedbackItem(id: 2, targetID: "hero", feedbackClass: .dot, keyword: .burn, text: "-2"),
            feedbackItem(id: 3, targetID: "companion", feedbackClass: .dot, keyword: .burn, text: "-1"),
            feedbackItem(id: 4, targetID: "enemy", feedbackClass: .dot, keyword: .poison, text: "-3")
        ]
        #expect(
            CombatSFXMapper.uniqueClipIDs(for: items) == [SFXID.hitBurn, SFXID.hit]
        )
    }

    private func feedbackItem(
        id: Int = 1,
        targetID: String = "target",
        feedbackClass: CombatFeedbackClass,
        keyword: Keyword,
        text: String,
        secondary: String? = nil
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: id,
            sourceEventIDs: [id],
            actionGroupID: id,
            presentationIndex: 0,
            groupResultCount: 1,
            targetID: targetID,
            feedbackClass: feedbackClass,
            keyword: keyword,
            text: text,
            secondaryText: secondary,
            spawnSeed: id,
            lifetime: 0.8,
            availableAt: .now,
            expiresAt: .now.addingTimeInterval(0.8),
            reactionKind: .none
        )
    }
}
