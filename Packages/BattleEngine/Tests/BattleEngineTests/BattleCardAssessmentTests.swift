import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleCardAssessmentTests {
    @Test func `assessment targets the lowest living ally without advancing combat`() throws {
        var state = battle()
        state.roster.mutateRuntime(for: state.companion) { $0.currentHealth = 5 }
        let card = deal(.heal, in: &state)
        let rng = state.rng
        let playSerial = state.heroTalents.nextPlaySerial
        state.heroTalents.history[state.hero.id, default: HeroTalentHistory()].preparations.insert(.poisonDamage)
        let health = state.roster.companion.currentHealth
        for _ in 0 ..< 4 {
            let assessment = state.assessCard(card)
            #expect(assessment.denial == nil)
            #expect(assessment.targets.map(\.combatantID) == [state.companion.id])
            #expect(assessment.resources.isEmpty)
        }
        #expect(state.rng == rng)
        #expect(state.heroTalents.nextPlaySerial == playSerial)
        #expect(state.heroTalents.history[state.hero.id]?.preparations == [.poisonDamage])
        #expect(state.roster.companion.currentHealth == health)
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.companion.currentHealth > health)
    }

    @Test func `random outcomes expose only common targets and do not peek at the roll`() {
        var state = battle(heroMana: 6)
        let random = Ability(
            id: "choice", name: "Choice", tier: .skill,
            outcomeBranches: [
                AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .burn)]),
                AbilityOutcomeBranch(effects: [.shield(.block, 4)]),
            ],
        )
        let card = deal(random, in: &state)
        let rng = state.rng
        let assessment = state.assessCard(card)
        #expect(assessment.targets.isEmpty)
        #expect(assessment.resources.count == 1)
        #expect(assessment.resources.first?.amount == nil)
        #expect(state.rng == rng)
    }

    @Test func `panacea separates its cleanse recipient from its healing recipient`() throws {
        var state = battle()
        state.roster.mutateRuntime(for: state.hero) { $0.currentHealth = 5 }
        state.roster.mutateRuntime(for: state.companion) { $0.currentHealth = 20 }
        state.appendEffect(.poison(3), to: state.companion, sourceID: state.enemy.id, remainingTurns: 2)
        let ability = Ability(id: "panacea", name: "Panacea", tier: .ultimate, effects: [.panacea(baseHeal: 3, healPerDebuff: 2)])
        let card = deal(ability, in: &state)
        let targets = state.assessCard(card).targets
        #expect(targets.contains { $0.combatantID == state.companion.id && $0.intent == .effect(.cleanse(nil)) })
        #expect(targets.contains { $0.combatantID == state.hero.id && $0.intent == .effect(.instantHeal(.health, 3)) })
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.hero.currentHealth > 5)
        #expect(!state.roster.companion.activeEffects.contains { $0.effect.keyword == .poison })
    }

    @Test func `damage intent reflects an active keyword conversion`() {
        var state = battle()
        state.appendEffect(.damageKeywordOverride(.holy, 1, 2), to: state.hero, sourceID: state.hero.id, remainingTurns: 2)
        let card = deal(.slash, in: &state)
        #expect(state.assessCard(card).targets.first?.intent == .damage(.holy))
    }

    @Test func `healing after a leeching hit does not promise the pre-hit lowest ally`() throws {
        var state = battle()
        state.roster.mutateRuntime(for: state.hero) { $0.currentHealth = 5 }
        state.roster.mutateRuntime(for: state.companion) { $0.currentHealth = 6 }
        let ability = Ability(
            id: "leech-heal", name: "Leech Heal", tier: .skill, directDamage: 10,
            effects: [.instantHeal(.health, 3)], criticalChanceBonus: -1, hasLeech: true,
        )
        let card = deal(ability, in: &state)
        #expect(state.assessCard(card).targets.allSatisfy { $0.combatantID == state.enemy.id })
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.companion.currentHealth > 6)
    }

    @Test(arguments: [2, 3, 4])
    func `health cost preview and denial use the same strict affordability rule`(health: Int) throws {
        var state = battle()
        state.roster.mutateRuntime(for: state.hero) { $0.currentHealth = health }
        let card = deal(.darkPact, in: &state)
        let assessment = state.assessCard(card)
        if health <= 3 {
            #expect(assessment.denial == .insufficientHealth)
            #expect(throws: BattlePlayError.insufficientHealth) { try state.playCard(cardID: card.id) }
        } else {
            #expect(assessment.resources.first?.keyword == .health)
            #expect(assessment.resources.first?.amount == 3)
            _ = try state.playCard(cardID: card.id)
            #expect(state.roster.hero.currentHealth == 1)
        }
    }

    @Test func `shared discounted empowerment quotes both actual payers`() throws {
        var hero = CombatModifierProfile.zero
        hero.triggers.empowermentCostReduction = 1
        var companion = CombatModifierProfile.zero
        companion.triggers.dragonPatronage = true
        var state = battle(heroMana: 1, companionMana: 5, heroModifiers: hero, companionModifiers: companion)
        let card = deal(.frostbolt, in: &state)
        let uses = state.assessCard(card).resources
        #expect(uses.first { $0.combatantID == state.hero.id }?.amount == 1)
        #expect(uses.first { $0.combatantID == state.companion.id }?.amount == 1)
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.hero.currentMana == 0)
        #expect(state.roster.companion.currentMana == 4)
    }

    @Test func `repeated empowerment quotes total spend with first purchase discount`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.empowermentCostReduction = 1
        profile.triggers.firstEmpowermentCostReduction = 1
        var state = battle(heroMana: 8, heroModifiers: profile)
        let ability = Ability(
            id: "repeat", name: "Repeat", tier: .skill,
            directDamage: 1, damageKeyword: .burn, repeatsManaEmpowerment: true,
        )
        let card = deal(ability, in: &state)
        #expect(state.assessCard(card).resources.first?.amount == 7)
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.hero.currentMana == 1)
    }

    @Test func `block substitution is quoted without treating missing mana as denial`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.freezeEmpowermentBlockPerMana = 3
        var state = battle(heroMana: 1, heroModifiers: profile)
        DefensePoolEngine.set(8, on: state.hero, in: &state)
        let card = deal(.frostbolt, in: &state)
        let assessment = state.assessCard(card)
        #expect(assessment.denial == nil)
        #expect(assessment.resources.first { $0.keyword == .block }?.amount == 6)
        _ = try state.playCard(cardID: card.id)
        #expect(DefensePoolEngine.blockPoints(in: state.roster.hero.activeEffects) == 2)
    }

    @Test func `mana conversion previews the whole balance while an unempowered attack remains playable`() throws {
        var state = battle(heroMana: 5)
        let conversion = deal(.manaShield, in: &state)
        #expect(state.assessCard(conversion).resources.first?.amount == 5)
        _ = try state.playCard(cardID: conversion.id)
        #expect(state.roster.hero.currentMana == 0)
        let attack = deal(.frostbolt, in: &state)
        #expect(state.assessCard(attack).denial == nil)
        #expect(state.assessCard(attack).resources.isEmpty)
    }

    @Test func `control and stale cards retain distinct denial reasons`() {
        var state = battle()
        let card = deal(.slash, in: &state)
        state.ownersSkippingThisPlayerTurn.insert(.hero)
        #expect(state.assessCard(card).denial == .ownerSkipping)
        state.ownersSkippingThisPlayerTurn.remove(.hero)
        _ = state.hand.remove(id: card.id)
        #expect(state.assessCard(card).denial == .cardNotInHand)
    }

    private func battle(
        heroMana: Int = 0, companionMana: Int = 0,
        heroModifiers: CombatModifierProfile = .zero, companionModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100, maxMana: 12),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100, maxMana: 12),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            heroMana: heroMana, companionMana: companionMana,
            heroModifiers: heroModifiers, companionModifiers: companionModifiers,
        )
        state.appliesFightPacing = false
        return state
    }

    private func deal(_ ability: Ability, in state: inout BattleState) -> BattleCard {
        BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
    }
}
