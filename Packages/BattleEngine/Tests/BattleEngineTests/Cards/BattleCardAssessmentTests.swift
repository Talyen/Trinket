import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleCardAssessmentTests {
    @Test func `Meteor inspection quotes capped Mana without iterating over every empowerment`() throws {
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100, maxMana: Int.max),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            heroMana: Int.max, appliesFightPacing: false,
        )
        let card = deal(.meteor, in: &state)
        let use = try #require(state.assessCard(card).resources.first { $0.keyword == .mana })
        #expect(use.amount == Int.max / 3 * 3)
        #expect(state.roster.hero.currentMana == Int.max)
    }

    @Test func `pack tactics previews its opening hit without guessing automatic recipients`() {
        var state = battle()
        let card = deal(.packTactics, in: &state)
        let targets = state.assessCard(card).targets
        #expect(targets.count == 1)
        #expect(targets.first?.combatantID == state.enemy.id)
        #expect(targets.first?.intent == .damage(.physical))
    }

    @Test func `blessed aegis assessment includes actor defense and enemy damage`() {
        var state = battle()
        let card = deal(.blessedAegis, in: &state)
        let targets = state.assessCard(card).targets
        #expect(targets.contains {
            $0.combatantID == state.hero.id && $0.intent == .effect(.shield(.block, 4))
        })
        #expect(targets.contains {
            $0.combatantID == state.enemy.id && $0.intent == .damage(.holy)
        })
    }

    @Test func `assessment targets the lowest living ally without advancing combat`() throws {
        var state = battle()
        state.roster.mutateRuntime(for: state.companion) { $0.currentHealth = 5 }
        let card = deal(.heal, in: &state)
        let rng = state.rng
        let playSerial = state.resolution.nextCardID
        state.roster.mutateRuntime(for: state.hero) { $0.talents.history.preparations.insert(.doublePoison) }
        let health = state.roster.companion.currentHealth
        for _ in 0 ..< 4 {
            let assessment = state.assessCard(card)
            #expect(assessment.denial == nil)
            #expect(assessment.targets.map(\.combatantID) == [state.companion.id])
            #expect(assessment.resources.isEmpty)
        }
        #expect(state.rng == rng)
        #expect(state.resolution.nextCardID == playSerial)
        #expect(state.roster.combatant(for: state.hero.id)?.talents.history.preparations == [.doublePoison])
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

    @Test func `astral arrow promises enemy damage without choosing its random element`() {
        var state = battle()
        let card = deal(.astralArrow, in: &state)
        let rng = state.rng
        let assessment = state.assessCard(card)
        #expect(assessment.targets.count == 1)
        #expect(assessment.targets.first?.combatantID == state.enemy.id)
        #expect(assessment.targets.first?.intent == .damage(nil))
        #expect(state.rng == rng)
    }

    @Test func `panacea leaves healing unresolved after debuff removal`() throws {
        var state = battle()
        state.roster.mutateRuntime(for: state.hero) { $0.currentHealth = 5 }
        state.roster.mutateRuntime(for: state.companion) { $0.currentHealth = 20 }
        state.insertEffect(.poison(3), to: state.companion, sourceID: state.enemy.id, remainingTurns: 2)
        let ability = Ability(id: "panacea", name: "Panacea", tier: .ultimate, effects: [.panacea(baseHeal: 3, healPerDebuff: 2)])
        let card = deal(ability, in: &state)
        let targets = state.assessCard(card).targets
        #expect(targets == [.init(combatantID: state.companion.id, intent: .effect(.cleanse(nil)))])
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.hero.currentHealth > 5)
        #expect(!state.roster.companion.activeEffects.contains { $0.effect.keyword == .poison })
    }

    @Test(arguments: [false, true])
    func `Panacea healing cue accounts for a preceding Fresh Batch heal`(hasDebuff: Bool) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatantTalentCatalog.profile(for: ["alchemist_cleanse_t1_2"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 5
        battle.roster.companion.currentHealth = 6
        if hasDebuff {
            battle.insertEffect(.poison(1), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 2)
        }
        battle.nextCardID += 1
        let card = BattleCard(id: battle.nextCardID, ability: .panaceaPotion, owner: .hero)
        battle.hand.append(card)

        let rng = battle.rng
        let targets = battle.assessCard(card).targets
        #expect(battle.rng == rng)
        #expect(battle.roster.hero.currentHealth == 5)
        #expect(battle.roster.companion.currentHealth == 6)
        #expect(targets.contains { $0.intent == .effect(.cleanse(nil)) })
        let healingTargets = targets.filter {
            if case .effect(.instantHeal(.health, _)) = $0.intent {
                return true
            }
            return false
        }
        #expect(healingTargets.map(\.combatantID) == (hasDebuff ? [] : [battle.hero.id]))

        let events = try battle.playCard(cardID: card.id).events
        let heal = try #require(events.first {
            $0.abilityName == Ability.panaceaPotion.name && $0.effectKind == .instantHeal
        })
        #expect(heal.targetID == (hasDebuff ? battle.companion.id : battle.hero.id))
        #expect(events.contains { $0.abilityName == "Fresh Batch" } == hasDebuff)
    }

    @Test func `damage intent reflects an active keyword conversion`() {
        var state = battle()
        state.insertEffect(.damageKeywordOverride(.holy, 1, 2), to: state.hero, sourceID: state.hero.id, remainingTurns: 2)
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

    @Test(arguments: [1, 2, 4])
    func `health cost preview and denial use the same strict affordability rule`(health: Int) throws {
        var state = battle()
        state.roster.mutateRuntime(for: state.hero) { $0.currentHealth = health }
        let card = deal(.darkPact, in: &state)
        let assessment = state.assessCard(card)
        if health <= 1 {
            #expect(assessment.denial == .insufficientHealth)
            #expect(throws: BattlePlayError.insufficientHealth) { try state.playCard(cardID: card.id) }
        } else {
            #expect(assessment.resources.first?.keyword == .health)
            #expect(assessment.resources.first?.amount == 1)
            _ = try state.playCard(cardID: card.id)
            #expect(state.roster.hero.currentHealth == health - 1)
        }
    }

    @Test func `shared discounted empowerment quotes both actual payers`() throws {
        var state = battle(
            heroMana: 1,
            companionMana: 5,
            heroModifiers: .withTriggers { $0.empowermentCostReduction = 1 },
            companionModifiers: .withTriggers { $0.dragonPatronage = true },
        )
        let card = deal(.frostbolt, in: &state)
        let uses = state.assessCard(card).resources
        #expect(uses.first { $0.combatantID == state.hero.id }?.amount == 1)
        #expect(uses.first { $0.combatantID == state.companion.id }?.amount == 1)
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.hero.currentMana == 0)
        #expect(state.roster.companion.currentMana == 4)
    }

    @Test func `meteor quotes predictable Pyromancers Spark discounted mana spend`() throws {
        var state = battle(heroMana: 8, heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_burn_t3_2"]))
        let card = deal(.meteor, in: &state)
        let rng = state.rng
        #expect(state.assessCard(card).resources.first { $0.keyword == .mana }?.amount == 8)
        #expect(state.rng == rng)
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.hero.currentMana == 0)
    }

    @Test func `repeated empowerment quotes total spend with first purchase discount`() throws {
        var state = battle(heroMana: 8, heroModifiers: .withTriggers {
            $0.empowermentCostReduction = 1
            $0.firstEmpowermentCostReduction = 1
        })
        let ability = Ability(
            id: "repeat", name: "Repeat", tier: .skill,
            directDamage: 1, damageKeyword: .burn, repeatsManaEmpowerment: true,
        )
        let card = deal(ability, in: &state)
        #expect(state.assessCard(card).resources.first?.amount == 7)
        _ = try state.playCard(cardID: card.id)
        #expect(state.roster.hero.currentMana == 1)
    }

    @Test func `repeated empowerment leaves its cost uncertain when spending can restore Mana`() throws {
        var state = battle(heroMana: 3, heroModifiers: .withTriggers {
            $0.onReachZeroManaRestoreMana = 3
            $0.criticalChanceBonus = -1
        })
        let ability = Ability(
            id: "repeat-restoration", name: "Repeat Restoration", tier: .skill,
            directDamage: 1, damageKeyword: .burn, repeatsManaEmpowerment: true,
        )
        let card = deal(ability, in: &state)
        let use = try #require(state.assessCard(card).resources.first { $0.keyword == .mana })
        #expect(use.amount == nil)
        let events = try state.playCard(cardID: card.id).events
        #expect(events.filter { $0.effectKind == .resourceGain && $0.keyword == .mana }.map(\.amount) == [3])
        #expect(events.filter { $0.kind == .abilityDamage && $0.abilityID == ability.id }.map(\.amount) == [3])
        #expect(state.mana(of: state.hero) == 0)
    }

    @Test func `block substitution is quoted without treating missing mana as denial`() throws {
        var state = battle(heroMana: 1, heroModifiers: .withTriggers { $0.freezeEmpowermentBlockPerMana = 3 })
        DefensePoolEngine.set(8, on: state.hero, in: &state)
        let card = deal(.frostbolt, in: &state)
        let assessment = state.assessCard(card)
        #expect(assessment.denial == nil)
        #expect(assessment.resources.first { $0.keyword == .block }?.amount == 6)
        _ = try state.playCard(cardID: card.id)
        #expect(DefensePoolEngine.blockPoints(in: state.roster.hero.activeEffects) == 2)
    }

    @Test func `mana conversion after Block gain stays uncertain while an unempowered attack remains playable`() throws {
        var state = battle(heroMana: 5)
        let ability = Ability(
            id: "mana-conversion", name: "Mana Conversion", tier: .skill,
            effects: [.shield(.block, 1), .convertManaToBlock],
        )
        let conversion = deal(ability, in: &state)
        let manaUse = try #require(state.assessCard(conversion).resources.first { $0.keyword == .mana })
        #expect(manaUse.amount == nil)
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

    @Test(arguments: [5, 6])
    func `scaled Health costs share affordability quotes and execution`(health: Int) throws {
        var state = battle()
        state.roster.hero.currentHealth = health
        DefensePoolEngine.set(10, on: state.hero, in: &state)
        let ability = Ability(
            id: "scaled-cost", name: "Scaled Cost", tier: .basic,
            damageComponents: [DamageComponent(0, target: .actor, scaling: .actorBlockFraction(divisor: 2, minimum: 1))],
        )
        let card = deal(ability, in: &state)
        let assessment = state.assessCard(card)
        if health == 5 {
            #expect(assessment.denial == .insufficientHealth)
            #expect(throws: BattlePlayError.insufficientHealth) { try state.playCard(cardID: card.id) }
            #expect(state.health(of: state.hero) == health)
            #expect(state.hand.card(id: card.id) == card)
        } else {
            #expect(assessment.resources.first { $0.keyword == .health }?.amount == 5)
            _ = try state.playCard(cardID: card.id)
            #expect(state.health(of: state.hero) == 1)
        }
    }

    @Test(arguments: [2, 3])
    func `fallback random outcomes cannot bypass Health affordability`(health: Int) throws {
        var state = battle()
        state.turnCount = 1
        state.roster.hero.currentHealth = health
        let ability = Ability(
            id: "fallback-cost", name: "Fallback Cost", tier: .basic,
            outcomeBranches: [AbilityOutcomeBranch(
                damageComponents: [DamageComponent(2, target: .actor), DamageComponent(1)],
                condition: .firstTurn,
            )],
            criticalChanceBonus: -1,
        )
        let card = deal(ability, in: &state)
        let rng = state.rng
        let assessment = state.assessCard(card)
        #expect(state.rng == rng)
        if health == 2 {
            #expect(assessment.denial == .insufficientHealth)
            #expect(throws: BattlePlayError.insufficientHealth) { try state.playCard(cardID: card.id) }
            #expect(state.health(of: state.hero) == health)
        } else {
            #expect(assessment.targets.contains { $0.combatantID == state.enemy.id })
            #expect(assessment.resources.first { $0.keyword == .health }?.amount == 2)
            _ = try state.playCard(cardID: card.id)
            #expect(state.health(of: state.hero) == 1)
        }
    }

    @Test func `Mana conversion after restoration does not quote the old balance`() throws {
        var state = battle(heroMana: 0)
        let ability = Ability(
            id: "restore-convert", name: "Restore and Convert", tier: .skill,
            targetedEffects: [
                TargetedEffect(.resourceGain(.mana, 4), target: .actor),
                TargetedEffect(.convertManaToBlock, target: .actor),
            ],
        )
        let card = deal(ability, in: &state)
        let use = try #require(state.assessCard(card).resources.first { $0.keyword == .mana })
        #expect(use.amount == nil)
        #expect(use.combatantID == state.hero.id)
        _ = try state.playCard(cardID: card.id)
        #expect(state.mana(of: state.hero) == 0)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.hero)) == 4)
    }

    @Test func `party Mana conversion includes both living payers`() throws {
        var state = battle(heroMana: 3, companionMana: 5)
        let ability = Ability(
            id: "party-convert", name: "Party Conversion", tier: .skill,
            targetedEffects: [TargetedEffect(.convertManaToBlock, target: .eachAlly)],
        )
        let card = deal(ability, in: &state)
        let uses = state.assessCard(card).resources
        #expect(Set(uses.map(\.combatantID)) == [state.hero.id, state.companion.id])
        _ = try state.playCard(cardID: card.id)
        #expect(state.mana(of: state.hero) == 0)
        #expect(state.mana(of: state.companion) == 0)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.hero)) == 3)
        #expect(DefensePoolEngine.blockPoints(in: state.activeEffects(of: state.companion)) == 5)
    }

    private func battle(
        heroMana: Int = 0, companionMana: Int = 0,
        heroModifiers: CombatModifierProfile = .zero, companionModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100, maxMana: 12),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100, maxMana: 12),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            heroMana: heroMana, companionMana: companionMana,
            heroModifiers: heroModifiers, companionModifiers: companionModifiers, appliesFightPacing: false,
        )
    }

    private func deal(_ ability: Ability, in state: inout BattleState) -> BattleCard {
        BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
    }
}

extension BattleCardAssessmentTests {
    @Test(arguments: [(true, true), (true, false), (false, true)])
    func `Panacea healing cue accounts for damage reactions before healing`(heroAlive: Bool, hasDebuff: Bool) throws {
        var companion = CombatantTalentCatalog.profile(for: ["library_owl_cleanse_t3_1"])
        companion.triggers.criticalChanceBonus = -1
        var enemy = CombatModifierProfile.zero
        enemy.triggers.onBlockHitDealHoly = 2
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            heroHealth: heroAlive ? 5 : 0, companionHealth: 6,
            companionModifiers: companion, enemyModifiers: enemy, appliesFightPacing: false,
        )
        if hasDebuff {
            state.insertEffect(.poison(1), to: state.companion, sourceID: state.enemy.id, remainingTurns: 2)
        }
        DefensePoolEngine.set(6, on: state.enemy, in: &state)
        let card = BattleCardCombatEngine.deal(.panaceaPotion, owner: .companion, context: &state)

        let rng = state.rng
        let targets = state.assessCard(card).targets
        #expect(state.rng == rng)
        #expect(state.health(of: state.companion) == 6)
        let healingTargets = targets.filter {
            if case .effect(.instantHeal(.health, _)) = $0.intent {
                return true
            }
            return false
        }
        let expectedCue = heroAlive ? state.hero.id : state.companion.id
        #expect(healingTargets.map(\.combatantID) == (heroAlive && hasDebuff ? [] : [expectedCue]))

        // Reproving Light hits the enemy's Block; its response lowers the Companion
        // below the Hero before Panacea chooses whom to heal.
        let events = try state.playCard(cardID: card.id).events
        let heal = try #require(events.first {
            $0.abilityName == Ability.panaceaPotion.name && $0.effectKind == .instantHeal
        })
        #expect(heal.targetID == (hasDebuff || !heroAlive ? state.companion.id : state.hero.id))
    }
}

extension BattleCardAssessmentTests {
    @Test func `composite aegis cues and execution retain the same constituent effects`() throws {
        var state = battle()
        let ability = Ability(
            id: "composite-aegis", name: "Composite Aegis", tier: .ultimate,
            effects: [.blessedAegis(block: 3, holyDamage: 2)],
        )
        let card = deal(ability, in: &state)
        let rng = state.rng
        let targets = state.assessCard(card).targets
        #expect(state.rng == rng)
        let effects: [Effect] = [.shield(.block, 3), .onHitDamage(.holy, 2)]
        #expect(targets.count == 4)
        for ally in [state.hero, state.companion] {
            for effect in effects {
                #expect(targets.contains { $0.combatantID == ally.id && $0.intent == .effect(effect) })
            }
        }
        _ = try state.playCard(cardID: card.id)
        for ally in [state.hero, state.companion] {
            for effect in effects {
                #expect(state.activeEffects(of: ally).contains { $0.effect == effect })
            }
        }
    }
}
