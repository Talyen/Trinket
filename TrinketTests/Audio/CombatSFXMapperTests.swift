import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
@testable import Trinket

@MainActor
struct CombatSFXMapperTests {
    @Test func physicalAndFallbackKeywordsMapToHit() {
        for keyword: Keyword in [.physical, .nature, .holy, .poison, .bleed, .leech] {
            let item = feedbackItem(feedbackClass: .directDamage, keyword: keyword, text: "-10")
            #expect(CombatSFXMapper.clipID(for: item) == SFXID.hit)
        }
    }

    @Test func criticalUsesSameHitClip() {
        let item = feedbackItem(feedbackClass: .critical, keyword: .physical, text: "-10", secondary: "CRIT")
        #expect(CombatSFXMapper.clipID(for: item) == SFXID.hit)
    }

    @Test func burnAndFreezeHitsMapToTypedClips() {
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
    }

    @Test func healAndCleanseMapToHeal() {
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
    }

    @Test func purgeMapsToPurge() {
        #expect(
            CombatSFXMapper.clipID(
                for: feedbackItem(feedbackClass: .buff, keyword: .block, text: "Purge Block")
            ) == SFXID.purge
        )
    }

    @Test func blockAndArmorBuffsMapToBlock() {
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
    }

    @Test func controlUsesFreezeOrStun() {
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
    }

    @Test func dodgeAndBlockAbsorbHaveNoSFX() {
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
    }

    @Test func deathsDoorMaps() {
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

    @Test func catalogContainsExpectedIDs() {
        let expected = [
            SFXID.uiTap, SFXID.uiConfirm, SFXID.uiCancel, SFXID.uiDecline, SFXID.uiDeny,
            SFXID.uiToggleOn, SFXID.uiToggleOff, SFXID.uiEquip, SFXID.uiUnequip, SFXID.uiBuySell,
            SFXID.abilityDraw, SFXID.abilityPlay,
            SFXID.hit, SFXID.hitBurn, SFXID.hitFreeze,
            SFXID.heal, SFXID.buff, SFXID.block,
            SFXID.controlFreeze, SFXID.controlStun,
            SFXID.purge, SFXID.deathsDoor,
            SFXID.victory, SFXID.defeat, SFXID.mysteryEvent,
        ]
        for id in expected {
            #expect(SFXCatalog.clipsByID[id] != nil, "Missing clip \(id)")
        }
        #expect(SFXCatalog.clips.count == expected.count)
    }

    private func feedbackItem(
        feedbackClass: CombatFeedbackClass,
        keyword: Keyword,
        text: String,
        secondary: String? = nil
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: 1,
            targetID: "target",
            feedbackClass: feedbackClass,
            keyword: keyword,
            text: text,
            secondaryText: secondary,
            spawnSeed: 1,
            lifetime: 0.8,
            availableAt: .now,
            expiresAt: .now.addingTimeInterval(0.8),
            reactionKind: .none
        )
    }
}
