import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketBattleFeature

/// Durable enemy that acts every turn, for presentation tests that need
/// repeated enemy actions without an early victory.
private func durableActingEnemy(abilities: [Ability]) -> Combatant {
    CombatantFixtures.passiveEnemy(
        maxHealth: 1000,
        actionIntervalTurns: CombatantFixtures.quickWinTurnInterval,
        abilities: abilities,
    )
}

@MainActor
struct BattleActionPresentationTests {
    @Test(arguments: [false, true])
    func `tap and prepared drag deliver all results once while attack motion continues`(prepared: Bool) throws {
        var sounds: [[String]] = []
        let environment = BattleRuntimeDependencies(
            playSFX: { sounds.append($0) }, warmSFX: { _, _ in }, hapticsEnabled: { true },
            effectsVolume: { 1 }, shouldAutoSkipUltimateCinematic: { _, _ in false },
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            autoEndTurnDelay: 60, presentationEnvironment: environment,
        )
        defer { session.endBattle() }
        let card = try installAttacks(in: session)[0]
        sounds.removeAll()
        let date = Date.now
        let enemyID = try #require(session.enemyID)
        let health = try #require(session.engineState?.roster.enemy.currentHealth)
        session.beginCardCue(card, mode: prepared ? .preview : .tapCommit)
        #expect(session.playCard(cardID: card.id, at: date) == .committed)
        #expect(session.canEndTurn)
        #expect((session.engineState?.roster.enemy.currentHealth ?? health) < health)
        #expect(session.feedback.activeItems.contains { $0.targetID == enemyID && $0.availableAt == date })
        let actorID = try #require(session.heroID)
        #expect(session.feedback.attackReactionsByCombatantID[actorID]?.phase == (prepared ? .swing : .windUp))
        let beat = try #require(session.feedback.scheduledActions.first { $0.actorID == actorID })
        #expect(abs(beat.swingAt.timeIntervalSince(beat.startAt) - (prepared ? 0 : 0.10)) < 0.001)
        let results = session.feedback.activeItems
        let immediateSounds = sounds
        #expect(immediateSounds.contains { !$0.isEmpty })
        #expect(session.feedback.hitReactionsByTargetID[enemyID] != nil)
        var hits: [Int] = []
        session.feedback.installHitReactionBridge(ownerID: UUID(), combatantID: enemyID) {
            if let reaction = $0 {
                hits.append(reaction.id)
            }
        }
        session.feedback.advance(to: beat.impactAt.addingTimeInterval(-0.001))
        #expect(hits.count == 1)
        session.feedback.advance(to: beat.impactAt)
        session.feedback.advance(to: beat.impactAt)
        #expect(hits.count == 1)
        #expect(session.feedback.activeItems == results)
        #expect(sounds == immediateSounds)
    }

    @Test(arguments: [false, true])
    func `play origin controls feedback even with auto battle enabled`(isAutomatic: Bool) throws {
        let environment = BattleRuntimeDependencies(
            playSFX: { _ in }, warmSFX: { _, _ in }, hapticsEnabled: { false }, effectsVolume: { 0 },
            rememberAutoBattlePreference: { true }, autoBattleEnabled: { true },
            shouldAutoSkipUltimateCinematic: { _, _ in false },
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            autoEndTurnDelay: 60, presentationEnvironment: environment,
        )
        defer { session.endBattle() }
        let card = try installAttacks(in: session)[0]
        #expect(session.isAutoBattleEnabled)
        #expect(session.playCard(cardID: card.id, isAutomatic: isAutomatic) == .committed)
        let beat = try #require(session.feedback.scheduledActions.first)
        #expect(session.feedback.activeItems.isEmpty == isAutomatic)
        #expect(abs(beat.swingAt.timeIntervalSince(beat.startAt) - (isAutomatic ? 0.40 : 0.10)) < 0.001)
        session.feedback.advance(to: beat.impactAt)
        #expect(!session.feedback.activeItems.isEmpty)
    }

    @Test(arguments: [Ability.block, .heal, .slash])
    func `a following manual card publishes results without waiting for earlier motion`(ability: Ability) throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        let first = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &state)
        let second = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        state.roster.hero.currentHealth = 50
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        let date = Date.now
        #expect(session.playCard(cardID: first.id, at: date) == .committed)
        let nextDate = date.addingTimeInterval(0.01)
        #expect(session.playCard(cardID: second.id, at: nextDate) == .committed)
        let beat = try #require(session.feedback.scheduledActions.last)
        #expect(beat.impactAt > nextDate)
        let expectedIDs = Set(CombatFeedbackPresenter.makeItems(from: beat.events, at: nextDate).flatMap(\.sourceEventIDs))
        #expect(!expectedIDs.isEmpty)
        #expect(expectedIDs.isSubset(of: Set(session.feedback.activeItems.flatMap(\.sourceEventIDs))))
        if ability == .heal {
            #expect(session.feedback.hitReactionsByTargetID[state.hero.id]?.kind == .heal)
        }
    }

    @Test func `prepared random support outcome releases attack wind up`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        var rng = state.rng
        let selected = try #require([0, 1].randomElement(using: &rng))
        var branches = Array(repeating: AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .physical)]), count: 2)
        branches[selected] = AbilityOutcomeBranch(effects: [.shield(.block, 3)])
        let ability = Ability(id: "prepared-choice", name: "Choice", tier: .basic, outcomeBranches: branches)
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        session.beginCardCue(card, mode: .preview)
        #expect(session.feedback.attackReactionsByCombatantID[state.hero.id]?.phase == .windUp)

        #expect(session.playCard(cardID: card.id) == .committed)

        #expect(session.engineState?.events.contains { $0.effectKind == .shieldApplied && $0.targetID == state.hero.id } == true)
        #expect(!session.feedback.previewActors.contains(state.hero.id))
        #expect(session.feedback.attackReactionsByCombatantID[state.hero.id]?.phase == .cancel)
        #expect(!session.feedback.scheduledActions.contains { $0.actorID == state.hero.id })
    }

    @Test(arguments: [0, 2, 100])
    func `direct hits react through partial and full block`(block: Int) throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        state.appliesFightPacing = false
        let attack = Ability(
            id: "recoil-test", name: "Hit", tier: .basic,
            damageComponents: [DamageComponent(10, keyword: .physical)], criticalChanceBonus: -1,
        )
        let card = BattleCardCombatEngine.deal(attack, owner: .hero, context: &state)
        DefensePoolEngine.set(block, on: state.enemy, in: &state)
        session.engineState = state
        session.installSimulationPresentation()
        #expect(session.playCard(cardID: card.id) == .committed)
        let impact = try #require(session.feedback.scheduledActions.first { $0.actorID == state.hero.id }?.impactAt)
        let reaction = try #require(session.feedback.hitReactionsByTargetID[state.enemy.id])
        #expect(reaction.kind == (block == 100 ? .block : .damage))
        session.feedback.advance(to: impact)
        #expect(session.feedback.hitReactionsByTargetID[state.enemy.id] == reaction)
    }

    @Test func `burst keeps every impact and shortens preparation`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let cards = try installAttacks(in: session)
        let date = Date.now
        var hits: [Int] = []
        let enemyID = try #require(session.enemyID)
        session.feedback.installHitReactionBridge(ownerID: UUID(), combatantID: enemyID) {
            if let reaction = $0 {
                hits.append(reaction.id)
            }
        }
        #expect(session.playCard(cardID: cards[0].id, at: date) == .committed)
        let originalImpact = try #require(session.feedback.scheduledActions.first?.impactAt)
        #expect(session.playCard(cardID: cards[1].id, at: date.addingTimeInterval(0.01)) == .committed)
        let beats = session.feedback.scheduledActions.filter { $0.actorID != nil }
        #expect(hits.count == 2)
        #expect(beats.count == 2)
        #expect(beats[0].impactAt < originalImpact)
        #expect(beats[1].swingAt >= beats[0].impactAt)
        for beat in beats {
            session.feedback.advance(to: beat.impactAt)
        }
        #expect(hits.count == 2)
        #expect(Set(hits).count == 2)
        let expectedIDs = Set(beats.flatMap { CombatFeedbackPresenter.makeItems(from: $0.events, at: date) }.flatMap(\.sourceEventIDs))
        #expect(!expectedIDs.isEmpty)
        #expect(expectedIDs.isSubset(of: Set(session.feedback.activeItems.flatMap(\.sourceEventIDs))))
    }

    @Test func `automatic cards share reveal and attack timing`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        state.companionDeck = CombatDeck(abilities: [.slash])
        let card = BattleCardCombatEngine.deal(.packTactics, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        #expect(session.playCard(cardID: card.id) == .committed)
        let cast = try #require(session.cardPlayback.casts.first)
        let beat = try #require(session.feedback.scheduledActions.first { $0.castID == cast.id })
        let parent = try #require(session.feedback.scheduledActions.first { $0.actorID == session.heroID })
        #expect(cast.startedAt >= parent.impactAt)
        #expect(cast.activationAt == beat.swingAt)
        #expect(beat.impactAt > beat.swingAt)
        #expect(beat.actorID == session.companionID)
        #expect(abs(beat.swingAt.timeIntervalSince(beat.startAt) - 0.40) < 0.001)
        #expect(!session.feedback.activeItems.contains { $0.actionGroupID == beat.id })
        session.feedback.advance(to: beat.impactAt)
        #expect(session.feedback.activeItems.contains { $0.actionGroupID == beat.id })
        #expect(session.canEndTurn)
    }

    @Test(arguments: [false, true], [Ability.slash, .block])
    func `enemy attacks use actual resolved actions`(skipped: Bool, ability: Ability) throws {
        let enemy = durableActingEnemy(abilities: [ability])
        let session = BattleSessionTestSupport.makeConfiguredSession(enemy: enemy)
        defer { session.endBattle() }
        var state = try #require(session.engineState)
        if skipped {
            state.appendEffect(.controlMeter(.stun, 10, 10), to: state.enemy, sourceID: state.hero.id, remainingTurns: 0)
        }
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        session.endTurn()
        let beats = session.feedback.scheduledActions.filter { $0.actorID == enemy.id }
        #expect(beats.isEmpty == (skipped || !ability.dealsCombatDamage))
        #expect(session.canEndTurn)
    }

    @Test func `suspension and end invalidate pending impacts`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let card = try installAttacks(in: session)[0]
        let date = Date.now
        #expect(session.playCard(cardID: card.id, at: date) == .committed)
        let impact = try #require(session.feedback.scheduledActions.first?.impactAt)
        session.feedback.setSuspended(true, at: date.addingTimeInterval(0.1))
        let pausedItems = session.feedback.activeItems
        session.feedback.advance(to: impact.addingTimeInterval(10))
        #expect(session.feedback.activeItems == pausedItems)
        #expect(!session.feedback.hitReactionsByTargetID.isEmpty)
        session.feedback.setSuspended(false, at: date.addingTimeInterval(10.1))
        let resumedImpact = try #require(session.feedback.scheduledActions.first?.impactAt)
        #expect(abs(resumedImpact.timeIntervalSince(impact) - 10) < 0.001)
        session.feedback.advance(to: resumedImpact)
        #expect(!session.feedback.activeItems.isEmpty)
        session.endBattle()
        session.feedback.advance(to: resumedImpact.addingTimeInterval(10))
        #expect(session.feedback.activeItems.isEmpty)
        #expect(session.feedback.scheduledActions.isEmpty)
        #expect(session.feedback.attackReactionsByCombatantID.isEmpty)
    }

    @Test func `attack retargeting and pause preserve the current pose`() {
        let date = Date.now
        var motion = CombatantAttackMotion()
        let windUp = CombatantAttackReaction(id: 1, phase: .windUp, startedAt: date)
        motion.adopt(windUp, aim: .towardEnemy)
        let interruptedAt = date.addingTimeInterval(0.2)
        let pose = motion.pose(at: interruptedAt, aim: .towardEnemy)
        motion.adopt(CombatantAttackReaction(id: 2, phase: .swing, startedAt: interruptedAt), aim: .towardEnemy)
        #expect(motion.pose(at: interruptedAt, aim: .towardEnemy) == pose)
        motion.reaction?.pausedAt = interruptedAt.addingTimeInterval(0.05)
        let paused = motion.pose(at: interruptedAt, aim: .towardEnemy)
        #expect(motion.pose(at: date.addingTimeInterval(10), aim: .towardEnemy) == paused)
    }

    @Test func `finishing casts cannot extend pending real impacts`() throws {
        let session = BattleSessionTestSupport.makePassiveSession(enemyHealth: 1)
        defer { session.endBattle() }
        session.outcomePresentationDelayOverride = nil
        let cards = try installAttacks(in: session)
        #expect(session.playCard(cardID: cards[0].id) == .committed)
        #expect(session.outcome == .victory)
        let deadline = try #require(session.feedback.pendingFeedbackEnd)
        let generation = session.spectacle.outcomeTask.generation
        let events = session.engineState?.events
        #expect(session.playCard(cardID: cards[1].id) == .committed)
        #expect(session.feedback.pendingFeedbackEnd == deadline)
        #expect(session.spectacle.outcomeTask.generation == generation)
        #expect(session.engineState?.events == events)
        let impact = try #require(session.feedback.scheduledActions.first?.impactAt)
        session.feedback.advance(to: impact)
        let enemyID = try #require(session.enemyID)
        #expect(session.feedback.hitReactionsByTargetID[enemyID] != nil)
        #expect(!session.spectacle.outcomePresentation.isOutcomePresented)
    }

    @Test func `cancelling preparation settles without an impact`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let card = try installAttacks(in: session)[0]
        session.beginCardCue(card)
        let actorID = try #require(session.heroID)
        #expect(session.feedback.attackReactionsByCombatantID[actorID]?.phase == .windUp)
        session.cancelCardCue(card)
        #expect(session.feedback.attackReactionsByCombatantID[actorID]?.phase == .cancel)
        #expect(session.feedback.scheduledActions.isEmpty)
        #expect(session.feedback.activeItems.isEmpty)
        #expect(session.hand.contains { $0.id == card.id })
    }

    @Test func `redirected damage reacts without changing combat events`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let original = try #require(session.engineState)
        let attack = Ability(
            id: "redirect-recoil", name: "Hit", tier: .basic,
            damageComponents: [DamageComponent(10, keyword: .physical, target: .hero)], criticalChanceBonus: -1,
        )
        let enemy = durableActingEnemy(abilities: [attack])
        var state = BattleState(
            hero: original.hero, companion: original.companion, enemy: enemy,
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t3_1"]),
            heroStartingHealth: 1, rngSeed: CombatantFixtures.deterministicBattleSeed, dealOpeningHand: false,
        )
        state.appliesFightPacing = false
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        var immediate = state
        let expectedEvents = immediate.endTurn()
        session.endTurn()
        let beat = try #require(session.feedback.scheduledActions.first { $0.actorID == enemy.id })
        #expect(session.engineState?.events == immediate.events)
        #expect(session.engineState?.rng == immediate.rng)
        #expect(session.engineState?.roster.hero.currentHealth == 1)
        #expect(session.engineState?.roster.companion == immediate.roster.companion)
        let received = try #require(beat.damage.first { $0.targetID == state.companion.id })
        guard case let .landed(_, healthLost) = received.impact else {
            Issue.record("The redirected hit must land on the companion")
            return
        }
        #expect(healthLost > 0)
        #expect(!expectedEvents.contains { $0.kind == .abilityDamage && $0.targetID == state.companion.id && $0.amount > 0 })
        session.feedback.advance(to: beat.impactAt)
        #expect(session.feedback.hitReactionsByTargetID[state.companion.id]?.kind == .damage)
        #expect(session.feedback.hitReactionsByTargetID[state.hero.id] == nil)
        session.feedback.setSuspended(true, at: beat.impactAt)
        session.feedback.pruneExpired(at: beat.impactAt.addingTimeInterval(10))
        #expect(session.feedback.hitReactionsByTargetID[state.companion.id] != nil)
        session.feedback.setSuspended(false, at: beat.impactAt.addingTimeInterval(10))
        session.feedback.advance(to: beat.impactAt.addingTimeInterval(12))
        #expect(session.feedback.hitReactionsByTargetID[state.companion.id] == nil)
    }

    @Test func `nested reaction logs do not move the counterattack before its cause`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let snapshot = try #require(session.presentationSnapshot())
        let configurationID = try #require(session.activeBattle?.id)
        let counter = BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .physical)
        let initial = BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 5, keyword: .physical)
        let playback = BattleTransitionPlayback(
            configurationID: configurationID, snapshot: snapshot, events: [counter, initial], automaticCards: [],
            actions: [
                BattleResolvedAction(id: 1, actorID: "hero", abilityID: "counter", cardID: nil, isAttack: true, eventIDs: [1]),
                BattleResolvedAction(id: 0, actorID: "enemy", abilityID: "hit", cardID: nil, isAttack: true, eventIDs: [2]),
            ],
        )
        var delivered: [Int] = []
        session.feedback.scheduleActions(
            playback, preparedCardID: nil, at: .now, cardPlayback: session.cardPlayback,
        ) { events, _, _, _ in
            delivered += events.map(\.id)
        }
        let beats = session.feedback.scheduledActions
        #expect(beats.map(\.actorID) == ["enemy", "hero"])
        for beat in beats {
            session.feedback.advance(to: beat.impactAt)
        }
        #expect(delivered == [2, 1])
    }
}

extension BattleActionPresentationTests {
    private func installAttacks(in session: BattleSession) throws -> [BattleCard] {
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        let cards = (0 ..< 2).map { _ in BattleCardCombatEngine.deal(.slash, owner: .hero, context: &state) }
        _ = BattleCardCombatEngine.deal(.block, owner: .companion, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        return cards
    }

    @Test(arguments: [Ability.avatarOfJustice, Ability(
        id: "recurring-recoil", name: "Recurring", tier: .skill,
        targetedEffects: [TargetedEffect(.recurringDamage(.burn, 6, 2))],
    )])
    func `immediate periodic card damage reacts but later ticks stay quiet`(ability: Ability) throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        let health = state.roster.enemy.currentHealth

        #expect(session.playCard(cardID: card.id) == .committed)

        let afterPlay = try #require(session.engineState?.roster.enemy.currentHealth)
        #expect(afterPlay < health)
        #expect(session.feedback.hitReactionsByTargetID[state.enemy.id]?.kind == .damage)
        session.feedback.clear()
        session.endTurn()
        #expect((session.engineState?.roster.enemy.currentHealth ?? afterPlay) < afterPlay)
        #expect(session.feedback.hitReactionsByTargetID[state.enemy.id] == nil)
    }
}
