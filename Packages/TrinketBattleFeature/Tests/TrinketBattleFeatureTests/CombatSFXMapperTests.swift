import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct CombatSFXMapperTests {
    @Test func `attacks and periodic damage share keyword cues`() {
        let mappings: [(Keyword, String)] = [
            (.physical, SFXID.hit), (.holy, SFXID.hitHoly), (.poison, SFXID.hitPiercing),
            (.bleed, SFXID.hitPiercing), (.leech, SFXID.hit), (.burn, SFXID.hitBurn),
            (.freeze, SFXID.hitFreeze), (.stun, SFXID.hitStun),
        ]
        for (keyword, clip) in mappings {
            for kind: ActionEvent.Kind in [.abilityDamage, .status] {
                #expect(CombatSFXMapper.clipID(for: [event(1, kind: kind, amount: 4, keyword: keyword)]) == clip)
            }
        }
    }

    @Test func `largest actual result wins and ties favor damage then healing`() {
        let moltenBulwark = [
            event(1, amount: 3, keyword: .burn),
            event(2, effect: .shieldApplied, amount: 4, keyword: .block),
            event(3, effect: .thornsApplied, amount: 4, keyword: .thorns),
        ]
        #expect(CombatSFXMapper.clipID(for: moltenBulwark) == SFXID.block)
        let blessedAegis = [
            event(1, effect: .shieldApplied, amount: 5, keyword: .block),
            event(2, effect: .instantHeal, amount: 5, keyword: .health, target: "hero"),
            event(3, amount: 5, keyword: .holy),
        ]
        #expect(CombatSFXMapper.clipID(for: blessedAegis) == SFXID.hitHoly)
        #expect(CombatSFXMapper.clipID(for: Array(blessedAegis.prefix(2))) == SFXID.heal)
    }

    @Test func `aggregation crosses targets but never merges effects sharing a clip`() {
        #expect(CombatSFXMapper.clipID(for: [
            event(1, amount: 4, keyword: .burn),
            event(2, effect: .instantHeal, amount: 2, keyword: .health, target: "hero"),
            event(3, effect: .instantHeal, amount: 3, keyword: .health, target: "companion"),
        ]) == SFXID.heal)
        #expect(CombatSFXMapper.clipID(for: [
            event(1, amount: 2, keyword: .bleed), event(2, amount: 2, keyword: .poison),
            event(3, effect: .instantHeal, amount: 3, keyword: .health),
        ]) == SFXID.heal)
        #expect(CombatSFXMapper.clipID(for: [
            event(1, amount: 2, keyword: .freeze), event(2, amount: 2, keyword: .freeze),
            event(3, amount: 3, keyword: .burn),
        ]) == SFXID.hitFreeze)
    }

    @Test func `structured impacts replace corresponding damage and absorption logs`() {
        let damage = BattleResolvedDamage(targetID: "enemy", keyword: .burn, impact: .landed(blocked: 5, healthLost: 3), isCritical: false)
        #expect(CombatSFXMapper.clipID(for: [
            event(1, amount: 3, keyword: .burn),
            event(2, effect: .shieldAbsorbed, amount: 5, keyword: .block, target: "hero"),
            event(3, effect: .instantHeal, amount: 8, keyword: .health),
        ], damage: [damage]) == SFXID.heal)
        #expect(CombatSFXMapper.clipID(for: [
            event(1, amount: 3, keyword: .burn),
            event(2, effect: .instantHeal, amount: 4, keyword: .health),
        ], damage: [.init(targetID: "enemy", keyword: .burn, impact: .landed(blocked: 0, healthLost: 3), isCritical: false)]) == SFXID.heal)
    }

    @Test func `partial absorption competes numerically while a dodge needs no amount`() {
        for (blocked, healthLost, clip) in [
            (5, 0, SFXID.blockAbsorb),
            (5, 2, SFXID.blockAbsorb),
            (2, 5, SFXID.hitBurn),
            (5, 5, SFXID.hitBurn),
        ] {
            #expect(CombatSFXMapper.clipID(for: [], damage: [
                .init(targetID: "enemy", keyword: .burn, impact: .landed(blocked: blocked, healthLost: healthLost), isCritical: false),
            ]) == clip)
        }
        #expect(CombatSFXMapper.clipID(for: [], damage: [
            .init(targetID: "hero", keyword: .physical, impact: .dodged, isCritical: false),
        ]) == SFXID.dodge)
    }

    @Test func `actual control and deaths door override numbers with stable source ties`() {
        let hit = event(1, amount: 99, keyword: .burn)
        let frozen = event(2, effect: .controlTriggered, keyword: .freeze)
        let stunned = event(3, effect: .controlTriggered, keyword: .stun)
        #expect(CombatSFXMapper.clipID(for: [hit, frozen, stunned]) == SFXID.controlFreeze)
        #expect(CombatSFXMapper.clipID(for: [hit, stunned, frozen]) == SFXID.controlStun)
        #expect(CombatSFXMapper.clipID(for: [hit, frozen, event(4, effect: .deathsDoorTriggered, keyword: .deathsDoor)]) == SFXID
            .deathsDoor)
        #expect(CombatSFXMapper.clipID(for: [event(1, amount: 3, keyword: .holy), event(2, amount: 3, keyword: .burn)]) == SFXID.hitHoly)
    }

    @Test func `costs overflow and future promises never inflate strength`() {
        #expect(CombatSFXMapper.clipID(for: [
            event(1, amount: 20, keyword: .physical, target: "hero"),
            event(2, amount: 3, keyword: .poison),
            event(3, effect: .instantHeal, amount: 1, keyword: .health),
            event(4, effect: .overheal, amount: 50, keyword: .health),
            event(5, effect: .criticalChanceApplied, amount: 100, keyword: .physical),
            event(6, effect: .thornsApplied, amount: 100, keyword: .thorns),
        ]) == SFXID.hitPiercing)
        #expect(CombatSFXMapper.clipID(for: [event(1, effect: .overheal, amount: 3, keyword: .health)]) == SFXID.heal)
    }

    @Test func `mana and draw are fallbacks instead of extra attack sounds`() {
        let mana = event(1, effect: .resourceGain, amount: 3, keyword: .mana)
        let draw = event(2, effect: .cardsDrawn, amount: 1, keyword: .mana)
        #expect(CombatSFXMapper.clipID(for: [mana, draw]) == SFXID.restoreMana)
        #expect(CombatSFXMapper.clipID(for: [mana, draw, event(3, amount: 1, keyword: .freeze)]) == SFXID.hitFreeze)
        #expect(CombatSFXMapper.clipID(for: [draw]) == SFXID.abilityDraw)
        #expect(CombatSFXMapper.clipID(for: [], didDrawCards: true) == SFXID.abilityDraw)
        #expect(CombatSFXMapper.clipID(for: [event(1, effect: .resourceGain, keyword: .mana)]) == nil)
        #expect(CombatSFXMapper.clipID(for: [event(1, effect: .resourceGain, amount: 3, keyword: .mana, origin: .automatic)]) == nil)
    }

    @Test func `stack application secondary debuffs and block costs remain silent`() {
        for effect: ActionEvent.EffectOutcome in [
            .recurringDamageApplied,
            .controlApplied,
            .shieldHalved,
            .blockStripped,
            .blockSpent,
            .markedApplied,
            .dotAmplified,
            .hemorrhageApplied,
        ] {
            #expect(CombatSFXMapper.clipID(for: [event(1, effect: effect, amount: 9, keyword: .poison)]) == nil)
        }
    }

    @Test func `selected outputs resolve in catalog and are battle prewarmed`() {
        let prewarmed = Set(CombatSFXMapper.battlePrewarmIDs)
        for keyword in Keyword.allCases {
            for effect in ActionEvent.EffectOutcome.allCases {
                guard let clip = CombatSFXMapper.clipID(for: [event(1, effect: effect, amount: 1, keyword: keyword)]) else { continue }
                #expect(SFXCatalog.clipsByID[clip] != nil)
                #expect(prewarmed.contains(clip))
            }
            let clip = CombatSFXMapper.clipID(for: [event(1, amount: 1, keyword: keyword)])
            #expect(clip.map(prewarmed.contains) == true)
        }
        for clip in prewarmed {
            #expect(SFXCatalog.clipsByID[clip] != nil)
        }
    }

    private func event(
        _ id: Int, kind: ActionEvent.Kind = .abilityDamage, effect: ActionEvent.EffectOutcome? = nil,
        amount: Int = 0, keyword: Keyword, target: String = "enemy", origin: ActionEvent.Origin = .direct,
    ) -> ActionEvent {
        ActionEvent(
            id: id, actionID: 1, kind: effect == nil ? kind : .effect, effectKind: effect,
            actorID: "hero", actorName: "Hero", abilityID: "test", abilityName: "Test",
            targetID: target, targetName: target, amount: amount, keyword: keyword, origin: origin,
        )
    }
}
