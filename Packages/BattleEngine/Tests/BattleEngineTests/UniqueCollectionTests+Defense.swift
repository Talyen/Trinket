import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test func `unclosing wound preserves duration then halves to expiration`() throws {
        var context = try battle(["the_unclosing_wound"], extra: CombatModifierProfile(bleedDurationBonus: 2))
        let target = context.roster.enemy.combatant
        _ = DoTApplicator.applyBleed(
            potency: 8,
            to: target,
            sourceActorID: context.roster.hero.id,
            dealImmediateDamage: false,
            in: &context,
        )
        let duration = Effect.bleedDoTTurnCount + 2
        for _ in 0 ..< duration {
            _ = EffectTurnEngine.advanceAll(context: &context)
        }
        #expect(context.roster.enemy.currentHealth == 2000 - 8 * duration)
        #expect(context.roster.enemy.activeEffects.first?.effect == .bleed(4))
        #expect(context.roster.enemy.activeEffects.first?.remainingTurns == 1)
        for _ in 0 ..< 3 {
            _ = EffectTurnEngine.advanceAll(context: &context)
        }
        #expect(context.roster.enemy.currentHealth == 2000 - 8 * duration - 7)
        #expect(context.roster.enemy.activeEffects.isEmpty)
    }

    @Test func `blackfletch includes companions unclosing bleed tail`() throws {
        let wound = try #require(GameContent.unique(matching: "the_unclosing_wound")?.affixPowers?.first)
        var companion = CombatModifierProfile(damageDealtBonus: [.bleed: 1])
        wound.triggers.apply(to: &companion)
        var context = try battle(["blackfletch"], other: companion)
        context.appendEffect(
            .bleed(8),
            to: context.roster.enemy.combatant,
            sourceID: context.roster.companion.id,
            remainingTurns: 2,
        )
        try play(attack(amount: 1), critical: true, in: &context)
        #expect(context.roster.enemy.currentHealth == 1970)
        #expect(!context.roster.hasAffliction(.bleed, on: context.roster.enemy.combatant))
    }

    @Test func `lingering bell restores buildup only after control recovery`() throws {
        var context = try battle(["the_lingering_bell"])
        let enemy = context.roster.enemy.combatant
        let sourceID = context.roster.hero.id
        _ = ControlMeterEngine.applyMeterCharge(
            900,
            keyword: .stun,
            to: enemy,
            sourceActorID: sourceID,
            applyFightPacing: false,
            in: &context,
        )
        #expect(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun))
        #expect(context.uniques.retainedStunByEffectID.values.first == 100)
        _ = ControlMeterEngine.applyMeterCharge(
            100,
            keyword: .stun,
            to: enemy,
            sourceActorID: sourceID,
            applyFightPacing: false,
            in: &context,
        )
        #expect(context.uniques.retainedStunByEffectID.values.first == 100)
        _ = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)
        #expect(context.roster.hasControlStatus(for: enemy, keyword: .stun))
        for _ in 0 ..< BattleTiming.controlStatusLingerTurns {
            _ = EffectTurnEngine.advanceAll(context: &context)
        }
        #expect(!context.roster.hasControlStatus(for: enemy, keyword: .stun))
        let meter = try #require(context.roster.enemy.activeEffects.first { $0.keyword == .stun })
        #expect(meter.effect.controlMeterValues?.amount == 100)
        _ = ControlMeterEngine.applyMeterCharge(
            300,
            keyword: .stun,
            to: enemy,
            sourceActorID: sourceID,
            applyFightPacing: false,
            in: &context,
        )
        #expect(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun))
    }

    @Test func `lingering bell retains reduced threshold and does not restore cleansed stun`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.enemyStunThresholdReductionPercent = 0.25
        var context = try battle(["the_lingering_bell"], extra: extra)
        let enemy = context.roster.enemy.combatant
        _ = ControlMeterEngine.applyMeterCharge(
            1000,
            keyword: .stun,
            to: enemy,
            sourceActorID: context.roster.hero.id,
            applyFightPacing: false,
            in: &context,
        )
        #expect(context.uniques.retainedStunByEffectID.values.first == 75)
        context.roster.setActiveEffects([], for: enemy)
        _ = UniqueCombatEngine.startTurn(in: &context)
        #expect(context.uniques.retainedStunByEffectID.isEmpty)
        #expect(context.roster.enemy.activeEffects.isEmpty)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `laughing guard spends pre grant block and only prevents passive decay`(owner: BattleParticipant) throws {
        var extra = CombatModifierProfile(damageDealtBonus: [.physical: 2])
        extra.triggers.dodgeBlockFlat = 4
        var context = try battle(["laughing_guard"], owner: owner, extra: extra)
        let actor = context.roster[owner].combatant
        block(9, owner: owner, in: &context)
        context.appendEffect(.evadeNextHit, to: actor, sourceID: actor.id, remainingTurns: 0)
        let hit = context.resolveDamage(DamageRequest(
            amount: 10,
            target: actor,
            keyword: .physical,
            sourceActorID: context.roster.enemy.id,
        ))
        #expect(hit.isDodged)
        #expect(context.roster.enemy.currentHealth == 1994)
        #expect(blockAmount(owner, in: context) == 9)
        DefensePoolEngine.decayBlock(on: actor, in: &context)
        #expect(blockAmount(owner, in: context) == 9)
        #expect(DefensePoolEngine.halveBlock(on: actor, in: &context))
        #expect(blockAmount(owner, in: context) == 4)
    }

    @Test func `companion call uses full basic once and cannot activate companions everkeen`() throws {
        let basic = Ability(
            id: "companion-basic",
            name: "Companion Basic",
            tier: .basic,
            directDamage: 4,
            effects: [.instantHeal(.health, 5), .shield(.block, 3)],
            criticalChanceBonus: -1,
        )
        let everkeen = try #require(GameContent.unique(matching: "everkeen")?.affixPowers?.first)
        var companion = CombatModifierProfile.zero
        everkeen.triggers.apply(to: &companion)
        var context = try battle(["huntsmasters_call"], other: companion, companionBasic: basic)
        context.roster.mutateRuntime(for: context.roster.companion.combatant) { $0.currentHealth = 100 }
        context.appendEffect(
            .nextStrikeCritical,
            to: context.roster.companion.combatant,
            sourceID: context.roster.companion.id,
            remainingTurns: 0,
        )
        let first = try play(attack(), critical: true, in: &context)
        #expect(context.roster.companion.currentHealth > 100)
        #expect(blockAmount(.companion, in: context) == 3)
        #expect(first.count(where: { $0.kind == .ability && $0.abilityID == basic.id }) == 1)
        #expect(!first.contains { $0.abilityName == "Everkeen" })
        #expect(context.uniques.owners[.companion]?.repeatedCritical != true)
        let next = try play(attack(), critical: true, in: &context)
        #expect(!next.contains { $0.kind == .ability && $0.abilityID == basic.id })
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `knights answer requires actual absorption and uses full basic`(owner: BattleParticipant) throws {
        let basic = Ability(id: "answer", name: "Answer", tier: .basic, effects: [.shield(.block, 3), .instantHeal(.health, 5)])
        var context = try battle(["the_knights_answer"], owner: owner, heroBasic: basic, companionBasic: basic)
        let actor = context.roster[owner].combatant
        context.roster.mutateRuntime(for: actor) { $0.currentHealth = 100 }
        _ = enemyHit(1, target: owner, in: &context)
        #expect(context.uniques.owners[owner]?.answeredBlock != true)
        block(10, owner: owner, in: &context)
        let first = enemyHit(5, target: owner, in: &context)
        #expect(blockAmount(owner, in: context) == 8)
        #expect(context.roster.health(for: actor) > 99)
        #expect(first.events.contains { $0.kind == .ability && $0.abilityID == "answer" })
        _ = enemyHit(1, target: owner, in: &context)
        #expect(blockAmount(owner, in: context) == 7)
    }

    @Test(arguments: [false, true])
    func `companion call skips unavailable companion`(defeated: Bool) throws {
        var context = try battle(["huntsmasters_call"])
        let companion = context.roster.companion.combatant
        if defeated {
            context.roster.mutateRuntime(for: companion) { $0.currentHealth = 0 }
        } else {
            context.appendEffect(
                .controlMeter(.stun, 40, 40),
                to: companion,
                sourceID: context.roster.enemy.id,
                remainingTurns: 0,
            )
        }
        let events = try play(attack(), critical: true, in: &context)
        #expect(!events.contains { $0.kind == .ability && $0.actorID == companion.id })
    }
}
