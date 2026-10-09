import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CounterattackCompanionRewardTests {
    @Test func `Knights Answer grants Bone Shield and shares its turn allowance with cards`() throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: ["risen_skeleton_physical_t1_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = try fixtures.battle(
            ["the_knights_answer"], owner: .companion, extra: profile, companionBasic: .slash,
        )
        fixtures.block(11, owner: .companion, in: &battle)

        let events = fixtures.enemyHit(1, target: .companion, in: &battle).events

        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id })
        #expect(events.contains { $0.abilityName == "Bone Shield" && $0.effectKind == .shieldApplied && $0.amount == 3 })
        #expect(fixtures.blockAmount(.companion, in: battle) == 13)

        let cardEvents = try fixtures.play(.slash, owner: .companion, in: &battle)
        #expect(!cardEvents.contains { $0.abilityName == "Bone Shield" })
        #expect(fixtures.blockAmount(.companion, in: battle) == 13)
    }

    @Test func `Knights Answer can draw the Wolfs Bloodrush card on a Bleed Critical Hit`() throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: ["wolf_bleed_t4_2"])
        profile.triggers.bleedCriticalDrawChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = try fixtures.battle(
            ["the_knights_answer"], owner: .companion, extra: profile, companionBasic: .fangs,
        )
        battle.companionDeck = CombatDeck(abilities: [.slash])
        fixtures.block(10, owner: .companion, in: &battle)
        battle.appendEffect(.nextStrikeCritical, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)

        let events = fixtures.enemyHit(1, target: .companion, in: &battle).events

        #expect(events.contains { $0.kind == .abilityDamage && $0.keyword == .bleed && $0.isCritical })
        #expect(events.contains { $0.abilityName == "Bloodrush" && $0.effectKind == .cardsDrawn && $0.amount == 1 })
        #expect(battle.hand.totalCount == 1)
        #expect(battle.hand.cards.first?.ability.id == Ability.slash.id)
    }
}
