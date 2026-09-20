import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CombatFeedbackPresenterTests {
    @Test(arguments: [0, 3, 10])
    func `healing feedback includes overflow in one health number`(restored: Int) throws {
        let events = [
            BattleSessionTestSupport.makeActionEvent(
                id: 1, kind: .effect, effectKind: .instantHeal, amount: restored, keyword: .health, actionID: 1,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 2, kind: .effect, effectKind: .overheal, amount: 10 - restored, keyword: .health,
                isCritical: true, actionID: 1,
            ),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)
        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.label == .amount(10))
        #expect(item.keyword == .health)
        #expect(item.feedbackClass == .heal)
        #expect(item.isCritical)
    }

    @Test func `filters merges and sums damage chips`() {
        let filtered = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .ability, amount: 5, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 5, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(id: 3, kind: .abilityDamage, amount: 0, keyword: .physical),
            ],
            at: Date(timeIntervalSince1970: 100),
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].id == 2)
        #expect(filtered[0].feedbackClass == .directDamage)

        let critical = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(
                    id: 10,
                    kind: .abilityDamage,
                    amount: 12,
                    keyword: .physical,
                    isCritical: true,
                ),
            ],
            at: Date(timeIntervalSince1970: 100),
        )
        #expect(critical.count == 1)
        #expect(critical[0].feedbackClass == .directDamage)
        #expect(critical[0].isCritical)
        #expect(critical[0].reactionKind == .damage)
        #expect(critical[0].sourceEventIDs == [10])

        let abilityItems = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .physical, actionID: 1),
                BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 4, keyword: .physical, actionID: 1),
            ],
            at: .now,
        )
        #expect(abilityItems.count == 1)
        #expect(abilityItems[0].text == "6")
        #expect(abilityItems[0].visualRole == .keyword)

        let sameKind = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 20, kind: .status, amount: 2, keyword: .bleed, actionID: 20),
                BattleSessionTestSupport.makeActionEvent(id: 21, kind: .status, amount: 3, keyword: .bleed, actionID: 20),
            ],
            at: .now,
        )
        #expect(sameKind.count == 1)
        #expect(sameKind[0].label == .amount(-5))
        #expect(sameKind[0].sourceEventIDs == [20, 21])

        let distinctKinds = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 30, kind: .abilityDamage, amount: 8, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(id: 31, kind: .status, amount: 3, keyword: .burn),
            ],
            at: .now,
        )
        #expect(distinctKinds.count == 2)
        #expect(Set(distinctKinds.map(\.feedbackClass)) == [.directDamage])
    }

    @Test func `afflicted aura name events do not produce chips`() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 8, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(
                    id: 2,
                    kind: .ability,
                    amount: 0,
                    keyword: .physical,
                    abilityName: "Intense Heat",
                ),
            ],
            at: Date(timeIntervalSince1970: 100),
        )
        #expect(items.count == 1)
        #expect(items[0].id == 1)
        #expect(items[0].feedbackClass == .directDamage)
    }

    @Test func `consolidates matching shield effects`() {
        let shields = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(
                    id: 7,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 2,
                    keyword: .block,
                    actionID: 7,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 8,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 3,
                    keyword: .block,
                    actionID: 7,
                ),
            ],
            at: .now,
        )
        #expect(shields.count == 1)
        #expect(shields[0].text == "5")
    }

    @Test(arguments: [0, 4])
    func `marked damage feedback matches actual health lost after block`(block: Int) throws {
        let ability = Ability(
            id: "feedback-marked", name: "Marked Hit", tier: .basic,
            damageComponents: [DamageComponent(5, keyword: .physical)],
            criticalChanceBonus: -1,
        )
        let hero = CombatantFixtures.passiveHero()
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 100)
        var battle = BattleState(
            hero: hero, companion: CombatantFixtures.passiveCompanion(), enemy: enemy,
            rngSeed: CombatantFixtures.deterministicBattleSeed, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(block, on: enemy, in: &battle)
        battle.appendEffect(.marked(3, 2), to: enemy, sourceID: hero.id, remainingTurns: 2)
        let healthBefore = battle.health(of: enemy)
        let events = BattleTurnEngine.performAction(ability: ability, actor: hero, abilityTarget: enemy, context: &battle)
        let marked = try #require(events.first { $0.effectKind == .markedConsumed })
        let damage = try #require(events.first { $0.kind == .abilityDamage })
        let healthLost = healthBefore - battle.health(of: enemy)
        #expect(marked.amount == 3)
        #expect(healthLost == 8 - block)
        #expect(damage.amount == healthLost)
        #expect(battle.events.contains(marked))

        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)
        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.label == .amount(-healthLost))
        #expect(item.sourceEventIDs == [damage.id])
    }

    @Test func `classifies heal and dodge`() {
        let events = [
            BattleSessionTestSupport.makeActionEvent(
                id: 4,
                kind: .effect,
                effectKind: .instantHeal,
                amount: 8,
                keyword: .health,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 5,
                kind: .effect,
                effectKind: .dodgeApplied,
                amount: 0,
                keyword: .dodge,
            ),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: Date(timeIntervalSince1970: 1))
        #expect(items.map(\.feedbackClass) == [.heal, .dodge])
        #expect(items[0].reactionKind == .heal)
        #expect(items[1].reactionKind == .dodge)
        #expect(items.count == 2)
        #expect(items[1].label == .word(.dodge))
    }

    @Test func `presenter leaves visual queue timing to battle session`() {
        let now = Date(timeIntervalSince1970: 1000)
        let sharedGroup = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(id: 2, kind: .status, amount: 4, keyword: .bleed, actionID: 1),
            ],
            at: now,
        )
        #expect(sharedGroup[0].availableAt == now)
        #expect(sharedGroup[1].availableAt == now)
        #expect(sharedGroup.map(\.actionGroupID) == [1, 1])

        let acrossTargets = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(
                    id: 2,
                    kind: .abilityDamage,
                    amount: 4,
                    keyword: .physical,
                    targetID: "hero",
                ),
            ],
            at: now,
        )
        #expect(acrossTargets[0].availableAt == now)
        #expect(acrossTargets[1].availableAt == now)
    }

    @Test func `keeps distinct feedback separate across targets kinds and damage classes`() {
        let acrossTargets = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .status, amount: 1, keyword: .bleed),
                BattleSessionTestSupport.makeActionEvent(
                    id: 2,
                    kind: .status,
                    amount: 2,
                    keyword: .bleed,
                    targetID: "hero",
                ),
            ],
            at: .now,
        )
        #expect(acrossTargets.count == 2)
        #expect(Set(acrossTargets.map(\.targetID)) == ["enemy", "hero"])

        let acrossKinds = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(
                    id: 1,
                    kind: .effect,
                    effectKind: .instantHeal,
                    amount: 2,
                    keyword: .health,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .leechHeal,
                    amount: 3,
                    keyword: .health,
                ),
            ],
            at: .now,
        )
        #expect(acrossKinds.count == 2)
        #expect(acrossKinds.map(\.text) == ["2", "3"])

        let directAndStatus = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .bleed),
                BattleSessionTestSupport.makeActionEvent(id: 2, kind: .status, amount: 1, keyword: .bleed),
            ],
            at: .now,
        )
        #expect(directAndStatus.map(\.feedbackClass) == [.directDamage, .directDamage])
    }

    @Test func `orders simultaneous results deterministically`() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .status, amount: 1, keyword: .bleed, actionID: 1),
                BattleSessionTestSupport.makeActionEvent(
                    id: 2, kind: .effect, effectKind: .resourceGain, amount: 1, keyword: .gold, actionID: 1,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 3, kind: .effect, effectKind: .instantHeal, amount: 2, keyword: .health, actionID: 1,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 4, kind: .effect, effectKind: .controlApplied, amount: 1, keyword: .stun, actionID: 1,
                ),
                BattleSessionTestSupport.makeActionEvent(id: 5, kind: .abilityDamage, amount: 8, keyword: .physical, actionID: 1),
                BattleSessionTestSupport.makeActionEvent(
                    id: 6, kind: .effect, effectKind: .shieldApplied, amount: 3, keyword: .block, actionID: 1,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 7, kind: .effect, effectKind: .dodgeApplied, amount: 0, keyword: .dodge, actionID: 1,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 8, kind: .effect, effectKind: .resourceGain, amount: 2, keyword: .mana, actionID: 1,
                ),
            ],
            at: .now,
        )
        #expect(items.count == 7)
        #expect(items[0].feedbackClass == .dodge)
        #expect(items[0].presentationIndex == 0)
        #expect(items.map(\.presentationIndex) == Array(0 ..< 7))
    }
}

extension CombatFeedbackPresenterTests {
    @Test @MainActor func `holy proc chain presents damage and healing instead of repeated benefits`() {
        let ability = Ability(
            id: "feedback-holy", name: "Holy Chain", tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .holy), DamageComponent(2, keyword: .holy), DamageComponent(2, keyword: .holy)],
            criticalChanceBonus: -1,
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 30, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 30)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var profile = CombatantTalentCatalog.profile(for: ["knight_holy_t1_1", "knight_block_t1_2", "knight_holy_t3_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleState(
            hero: hero, companion: companion, enemy: enemy,
            heroModifiers: profile, rngSeed: CombatantFixtures.deterministicBattleSeed,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        let events = BattleTurnEngine.performAction(ability: ability, actor: hero, abilityTarget: enemy, context: &battle)
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)
        #expect(events.count { $0.effectKind == .shieldApplied } == 3)
        #expect(events.count { $0.effectKind == .thornsApplied } == 3)
        #expect(events.count { $0.effectKind == .instantHeal } == 3)
        #expect(items.count == 2)
        #expect(items.first { $0.targetID == "enemy" }?.label == .amount(-6))
        #expect(items.first { $0.targetID == "hero" }?.label == .amount(12))
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        lane.record(events)
        #expect(Set(lane.hitReactionsByTargetID.keys) == ["hero", "enemy"])
    }

    @Test func `keeps same kind results separate across action I ds`() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 4, keyword: .burn, actionID: 10),
                BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 3, keyword: .burn, actionID: 11),
            ],
            at: .now,
        )
        #expect(items.count == 2)
        #expect(items.map(\.actionGroupID) == [10, 11])
        #expect(items.map(\.text) == ["4", "3"])
    }

    @Test func `overlay keeps all groups and emits one canvas chip per distinct kind`() {
        let first = CombatFeedbackPresenter.makeItems(
            from: [BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical)],
            at: Date(timeIntervalSince1970: 10),
        )
        let second = CombatFeedbackPresenter.makeItems(
            from: [BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 4, keyword: .burn)],
            at: Date(timeIntervalSince1970: 10.65),
        )

        let chips = CombatFeedbackOrdering.orderedChips(from: first + second)

        #expect(chips.map(\.id) == [1, 2])

        let mixed = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 7, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 4,
                    keyword: .block,
                ),
            ],
            at: Date(timeIntervalSince1970: 10),
        )
        let mixedChips = CombatFeedbackOrdering.orderedChips(from: mixed)

        #expect(mixedChips.count == 2)
        #expect(mixedChips.map(\.label) == [
            .amount(-7),
            .amount(4),
        ])
        #expect(mixedChips.map(\.feedbackClass) == [.directDamage, .buff])
        #expect(mixedChips.allSatisfy { !$0.label.displayString.contains("Effect") })
    }

    @Test func `keeps ability damage visible when effect kind would hide an effect chip`() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(
                    id: 1,
                    kind: .abilityDamage,
                    effectKind: .cardsDrawn,
                    amount: 6,
                    keyword: .physical,
                ),
            ],
            at: .now,
        )
        #expect(items.count == 1)
        #expect(items[0].feedbackClass == .directDamage)
        #expect(items[0].label == .amount(-6))
    }

    @Test func `suppresses cards control buildup and numeric zeroes but shows preparations`() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(id: 1, kind: .effect, effectKind: .cardsDrawn, amount: 2, keyword: .physical),
                BattleSessionTestSupport.makeActionEvent(id: 2, kind: .effect, effectKind: .controlApplied, amount: 4, keyword: .stun),
                BattleSessionTestSupport.makeActionEvent(id: 3, kind: .effect, effectKind: .shieldApplied, amount: 0, keyword: .block),
                BattleSessionTestSupport.makeActionEvent(
                    id: 4,
                    kind: .effect,
                    effectKind: .nextHolyStrikeApplied,
                    amount: 0,
                    keyword: .holy,
                ),
                BattleSessionTestSupport.makeActionEvent(id: 5, kind: .effect, effectKind: .leechApplied, amount: 10, keyword: .physical),
            ],
            at: .now,
        )

        #expect(items.count == 2)
        #expect(items[1].label == .word(.status(.leech)))
        #expect(items[0].label == .word(.status(.nextHolyStrike)))
        #expect(items[0].visualRole == .beneficialStatus)
    }

    @Test @MainActor func `routes resource and named status visuals`() throws {
        let now = Date.now
        let items = [
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .effect, effectKind: .resourceGain, amount: 3, keyword: .gold),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .effect, effectKind: .resourceGain, amount: 2, keyword: .mana),
            BattleSessionTestSupport.makeActionEvent(id: 3, kind: .effect, effectKind: .manaShieldTriggered, amount: 1, keyword: .mana),
            BattleSessionTestSupport.makeActionEvent(id: 4, kind: .effect, effectKind: .thornsApplied, amount: 2, keyword: .thorns),
            BattleSessionTestSupport.makeActionEvent(
                id: 6,
                kind: .effect,
                effectKind: .criticalChanceApplied,
                amount: 15,
                keyword: .physical,
            ),
            BattleSessionTestSupport.makeActionEvent(id: 7, kind: .effect, effectKind: .markedApplied, amount: 3, keyword: .physical),
            BattleSessionTestSupport.makeActionEvent(id: 8, kind: .effect, effectKind: .shieldHalved, amount: 0, keyword: .block),
        ].flatMap { CombatFeedbackPresenter.makeItems(from: [$0], at: now) }

        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        #expect(try #require(byID[4]).label == .word(.status(.thorns)))
        #expect(try #require(byID[6]).label == .word(.status(.criticalUp)))
        #expect(try #require(byID[7]).label == .word(.status(.marked)))
        #expect(try #require(byID[8]).label == .word(.status(.blockDown)))
    }

    @Test func `only direct benefits float while automatic healing remains visible`() {
        let events: [ActionEvent] = [
            feedbackEvent(1, .resourceGain, .mana, origin: .automatic),
            feedbackEvent(2, .resourceGain, .mana, origin: .direct),
            feedbackEvent(3, .shieldApplied, .block, origin: .automatic),
            feedbackEvent(4, .thornsApplied, .thorns, origin: .automatic),
            feedbackEvent(5, .instantHeal, .health, origin: .automatic),
            feedbackEvent(6, .leechHeal, .leech, origin: .periodic),
            feedbackEvent(7, .dotAmplified, .poison, origin: .direct),
            feedbackEvent(8, .recurringDamageApplied, .burn, origin: .direct),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)
        #expect(items.count == 4)
        #expect(items.contains { $0.label == .word(.status(.amplified)) })
        #expect(items.contains { $0.label == .word(.applied(.burn)) })
        #expect(items.first { $0.feedbackClass == .heal }?.label == .amount(4))
        #expect(items.first { $0.feedbackClass == .resource }?.sourceEventIDs == [2])
    }

    @Test func `only fully absorbed hits show block feedback`() {
        let items = CombatFeedbackPresenter.makeItems(from: [
            feedbackEvent(1, .shieldAbsorbed, .block, origin: .automatic),
            feedbackEvent(2, .shieldAbsorbed, .block, origin: .automatic, fullyBlocked: true),
        ], at: .now)
        #expect(items.map(\.sourceEventIDs) == [[2]])
    }

    private func feedbackEvent(
        _ id: Int, _ effect: ActionEvent.EffectOutcome, _ keyword: Keyword,
        origin: ActionEvent.Origin, fullyBlocked: Bool = false,
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            actionID: id,
            kind: .effect,
            effectKind: effect,
            actorName: "Hero",
            abilityName: "Same display name",
            targetID: "hero",
            targetName: "Hero",
            amount: 2,
            keyword: keyword,
            feedbackGroupID: 1,
            origin: origin,
            isFullyBlocked: fullyBlocked,
        )
    }

    @Test func `merges gold gains and suppresses gold loss chips`() throws {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                BattleSessionTestSupport.makeActionEvent(
                    id: 1,
                    kind: .effect,
                    effectKind: .resourceGain,
                    amount: 4,
                    keyword: .gold,
                    actionID: 1,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .resourceGain,
                    amount: 3,
                    keyword: .gold,
                    actionID: 1,
                ),
                BattleSessionTestSupport.makeActionEvent(
                    id: 3,
                    kind: .effect,
                    effectKind: .resourceGain,
                    amount: -3,
                    keyword: .gold,
                    actionID: 1,
                ),
            ],
            at: .now,
        )

        try #expect(items.count == 1)
        let gain = try #require(items.first)
        #expect(gain.label == .amount(7))
        #expect(gain.visualRole == .keyword)
    }
}
