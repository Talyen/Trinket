import TrinketContent
import TrinketCore

package enum BoonCombatEngine {
    static func ignoresDodge(for state: DamageResolutionState, in context: BattleState) -> Bool {
        state.damageKeyword == .holy
            && state.partySource(in: context) != nil
            && sourceHasBlock(state.sourceActorID, in: context)
            && context.activeBoons.contains { boon in
                if case .damageIgnoresBlockAndDodgeWhileBlocked(.holy) = boon.boon.effect {
                    true
                } else {
                    false
                }
            }
    }

    static func ignoresBlock(for state: DamageResolutionState, in context: BattleState) -> Bool {
        ignoresDodge(for: state, in: context)
    }

    static func guaranteesCritical(for state: DamageResolutionState, in context: BattleState) -> Bool {
        guard let keyword = state.damageKeyword, state.partySource(in: context) != nil else { return false }
        return context.activeBoons.contains { boon in
            if case let .goldGuaranteesCritical(required, threshold) = boon.boon.effect {
                return keyword == required && context.gold >= threshold
            }
            return false
        }
    }

    static func modifyDamage(_ state: inout DamageResolutionState, in context: inout BattleState) {
        guard let keyword = state.damageKeyword,
              let source = state.partySource(in: context),
              state.combatant.role == .enemy
        else { return }
        guard pushDepth(in: &context) else { return }
        defer { popDepth(in: &context) }

        for active in context.activeBoons where !context.boonRuntime.resolvingBoonIDs.contains(active.id) {
            switch active.boon.effect {
            case let .criticalDamageMultiplier(required, status, multiplier)
                where state.isCritical && keyword == required && targetHas(status, state: state):
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: multiplier)
            case let .statusDamageMultiplier(status, damage, multiplier)
                where keyword == damage && targetHas(status, state: state):
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: multiplier)
            case .consumeBlockForBonusDamage(.physical) where keyword == .physical:
                guard begin(active, in: &context) else { continue }
                let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant))
                if block > 0,
                   let reduced = DefensePoolEngine.reduce(block, in: context.roster.activeEffects(for: source.combatant)) {
                    context.roster.setActiveEffects(reduced.effects, for: source.combatant)
                    state.remaining += reduced.absorbed
                }
                end(active, in: &context)
            case .storedBlockedDamage(.physical) where keyword == .physical:
                guard begin(active, in: &context) else { continue }
                let stored = context.boonRuntime.storedBlockedDamageByActorID.removeValue(forKey: source.id) ?? 0
                if stored > 0 {
                    state.remaining += stored
                }
                end(active, in: &context)
            default:
                continue
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func afterDamage(_ state: DamageResolutionState, in context: inout BattleState) -> [ActionEvent] {
        guard let keyword = state.damageKeyword,
              let source = state.partySource(in: context),
              state.combatant.role == .enemy,
              state.amount > 0
        else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        var events: [ActionEvent] = []
        for active in context.activeBoons where begin(active, in: &context) {
            defer { end(active, in: &context) }
            switch active.boon.effect {
            case let .mirroredDamage(required, result, multiplier) where keyword == required:
                events += dealTypedDamage(
                    CombatRounding.scaled(state.buildupDamage, multiplier: multiplier),
                    keyword: result,
                    target: state.combatant,
                    source: source.combatant,
                    in: &context,
                )
            case let .damageGrantsPartyBlock(required) where keyword == required:
                events += grantPartyBlock(state.buildupDamage, source: source.combatant, name: active.boon.name, in: &context)
            case let .damageGrantsBlock(required) where keyword == required:
                events += context.applyBlock(
                    state.buildupDamage,
                    to: source.combatant,
                    source: source.combatant,
                    abilityName: active.boon.name,
                )
            case .freezeDamageStealsBlock where keyword == .freeze:
                events += stealEnemyBlock(state.blockedAmount, source: source.combatant, name: active.boon.name, in: &context)
            case let .damageRestoresMana(required) where keyword == required:
                events += context.restoreManaEmitting(state.buildupDamage, to: source.combatant, abilityName: active.boon.name)
            case let .damagePurgesAll(required) where keyword == required:
                let purged = purgeAll(from: state.combatant, source: source.combatant, name: active.boon.name, in: &context)
                events += purged.events
                events += damageAfterPurge(purged.count, target: state.combatant, source: source.combatant, in: &context)
            case let .damageDetonates(required, effect, requiresCritical)
                where keyword == required && (!requiresCritical || state.isCritical):
                events += detonate(effect, on: state.combatant, source: source.combatant, in: &context)
            case let .damageDrawsCard(required, cardKeyword) where keyword == required:
                events += drawCard(cardKeyword, for: source.combatant, name: active.boon.name, in: &context)
            case let .criticalDamageMultiplier(required, _, _) where state.isCritical && keyword == required:
                continue
            case let .criticalGoldAndDraw(gold, cards) where state.isCritical:
                events += context.grantGoldEvent(gold, to: source.combatant, abilityName: active.boon.name)
                if let owner = context.roster.participant(for: source.combatant) {
                    events += CombatTriggerEngine.drawCards(
                        cards,
                        for: owner,
                        actor: source.combatant,
                        abilityName: active.boon.name,
                        in: &context,
                    )
                }
            case let .criticalGrantsDodge(required) where state.isCritical && keyword == required:
                context.prependEffect(.evadeNextHit, to: source.combatant, remainingTurns: 0)
            case let .criticalDoublesBleedDuration(required) where state.isCritical && keyword == required:
                doubleBleedDuration(on: state.combatant, in: &context)
            default:
                continue
            }
        }
        return events
    }

    static func afterBlockedDamage(
        _ amount: Int,
        defender: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, defender.role != .enemy,
              let attackerID,
              let attacker = context.roster.combatant(for: attackerID)
        else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        var events: [ActionEvent] = []
        for active in context.activeBoons where begin(active, in: &context) {
            defer { end(active, in: &context) }
            switch active.boon.effect {
            case .storedBlockedDamage(.physical):
                context.boonRuntime.storedBlockedDamageByActorID[defender.id, default: 0] += amount
            case let .blockedDamageReturned(keyword):
                events += dealTypedDamage(amount, keyword: keyword, target: attacker.combatant, source: defender, in: &context)
            default:
                continue
            }
        }
        return events
    }

    static func afterControl(
        _ keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard target.role == .enemy,
              let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy
        else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        var events: [ActionEvent] = []
        for active in context.activeBoons where !context.boonRuntime.resolvingBoonIDs.contains(active.id) {
            guard case let .controlDoublesPartyBlock(required) = active.boon.effect,
                  required == keyword,
                  begin(active, in: &context)
            else { continue }
            defer { end(active, in: &context) }
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: member.combatant))
                guard member.isAlive, block > 0 else { continue }
                events += context.applyBlock(block, to: member.combatant, source: source.combatant, abilityName: active.boon.name)
            }
        }
        return events
    }

    static func afterManaSpent(_ amount: Int, by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard amount > 0, actor.role != .enemy, context.roster.enemy.isAlive else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        guard let active = context.activeBoons.first(where: {
            if case .manaSpentDealsDamage(.stun) = $0.boon.effect {
                !context.boonRuntime.resolvingBoonIDs.contains($0.id)
            } else {
                false
            }
        }), begin(active, in: &context) else { return [] }
        defer { end(active, in: &context) }
        return dealTypedDamage(amount, keyword: .stun, target: context.roster.enemy.combatant, source: actor, in: &context)
    }

    static func afterCleanse(_ count: Int, source: Combatant, target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard count > 0, source.role != .enemy else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        var events: [ActionEvent] = []
        for active in context.activeBoons where !context.boonRuntime.resolvingBoonIDs.contains(active.id) {
            guard case let .cleanseRestoresHealth(amount) = active.boon.effect,
                  begin(active, in: &context)
            else { continue }
            defer { end(active, in: &context) }
            events += context.healEmitting(amount: amount * count, target: target, source: source, abilityName: active.boon.name)
        }
        return events
    }

    static func afterOverheal(source: Combatant, target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard source.role != .enemy,
              let active = context.activeBoons.first(where: {
                  if case .overhealCleanses = $0.boon.effect {
                      !context.boonRuntime.resolvingBoonIDs.contains($0.id)
                  } else {
                      false
                  }
              }),
              pushDepth(in: &context),
              begin(active, in: &context)
        else { return [] }
        defer { popDepth(in: &context); end(active, in: &context) }
        return CombatTriggerEngine.performRandomCleanses(source: source, target: target, count: 1, abilityName: "Clean Slate", in: &context)
    }

    static func afterPurge(_ count: Int, source: Combatant, target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard source.role != .enemy else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        return damageAfterPurge(count, target: target, source: source, in: &context)
    }

    static func afterDodge(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard actor.role != .enemy else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        guard let active = context.activeBoons.first(where: {
            if case .dodgeDrawsAndPlays(.physical) = $0.boon.effect {
                !context.boonRuntime.resolvingBoonIDs.contains($0.id)
            } else {
                false
            }
        }),
            begin(active, in: &context),
            let owner = context.roster.participant(for: actor),
            let card = BattleCardCombatEngine.drawFirstCard(matching: .physical, for: owner, context: &context)
        else { return [] }
        defer { end(active, in: &context) }
        return (try? BattleCardCombatEngine.playDrawnCard(card, context: &context)) ?? []
    }

    static func afterCardPlayed(_ ability: Ability, actor: Combatant, target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard actor.role != .enemy else { return [] }
        guard pushDepth(in: &context) else { return [] }
        defer { popDepth(in: &context) }
        var events: [ActionEvent] = []
        for active in context.activeBoons where !context.boonRuntime.resolvingBoonIDs.contains(active.id) {
            guard case let .cardPrimesRepeat(trigger, repeated) = active.boon.effect else { continue }
            if ability.keywords.contains(trigger) {
                context.boonRuntime.primedRepeatKeywords.insert(repeated)
            } else if ability.keywords.contains(repeated), context.boonRuntime.primedRepeatKeywords.remove(repeated) != nil {
                guard begin(active, in: &context) else { continue }
                defer { end(active, in: &context) }
                events += BattleTurnEngine.performAction(ability: ability, actor: actor, abilityTarget: target, context: &context)
            }
        }
        return events
    }

    static func preservesBleed(on target: Combatant, in context: BattleState) -> Bool {
        context.roster.hasControlStatus(for: target, keyword: .freeze)
            && context.activeBoons.contains {
                if case .preserveBleedWhileFrozen = $0.boon.effect {
                    true
                } else {
                    false
                }
            }
    }
}

package extension BoonCombatEngine {
    private static func sourceHasBlock(_ sourceActorID: String?, in context: BattleState) -> Bool {
        guard let sourceActorID, let source = context.roster.combatant(for: sourceActorID) else { return false }
        return DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant)) > 0
    }

    private static func targetHas(_ keyword: Keyword, state: DamageResolutionState) -> Bool {
        switch keyword {
        case .stun: state.targetStatus.isStunned
        case .freeze: state.targetStatus.isFrozen
        case .burn: state.targetStatus.isBurning
        case .poison: state.targetStatus.isPoisoned
        case .bleed: state.targetStatus.isBleeding
        default: false
        }
    }

    private static func begin(_ active: ActiveBoon, in context: inout BattleState) -> Bool {
        context.boonRuntime.resolvingBoonIDs.insert(active.id).inserted
    }

    private static func end(_ active: ActiveBoon, in context: inout BattleState) {
        context.boonRuntime.resolvingBoonIDs.remove(active.id)
    }

    private static func pushDepth(in context: inout BattleState) -> Bool {
        guard context.boonRuntime.depth < BoonEngine.maxRecursionDepth else { return false }
        context.boonRuntime.depth += 1
        return true
    }

    private static func popDepth(in context: inout BattleState) {
        context.boonRuntime.depth = max(0, context.boonRuntime.depth - 1)
    }

    private static func dealTypedDamage(
        _ amount: Int,
        keyword: Keyword,
        target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: target) > 0 else { return [] }
        switch keyword {
        case .burn, .poison:
            return context.applyDecayingDoT(
                keyword: keyword,
                potency: amount,
                to: target,
                sourceActorID: source.id,
                dealImmediateDamage: true,
                suppressAffixReactions: true,
            )
        case .bleed:
            return DoTApplicator.applyBleed(
                potency: amount,
                to: target,
                sourceActorID: source.id,
                dealImmediateDamage: true,
                suppressAffixReactions: true,
                in: &context,
            )
        case .stun, .freeze:
            return context.resolveDamage(DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: false,
                    applyControlMeter: true,
                ),
            )).events
        default:
            return context.resolveDamage(DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: false,
                ),
            )).events
        }
    }

    private static func grantPartyBlock(_ amount: Int, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return [BattleParticipant.hero, .companion].flatMap { owner -> [ActionEvent] in
            let member = context.roster[owner]
            guard member.isAlive else { return [] }
            return context.applyBlock(amount, to: member.combatant, source: source, abilityName: name)
        }
    }

    private static func stealEnemyBlock(_ amount: Int, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return grantPartyBlock(amount, source: source, name: name, in: &context)
    }

    private static func purgeAll(
        from target: Combatant,
        source: Combatant,
        name: String,
        in context: inout BattleState,
    ) -> (count: Int, events: [ActionEvent]) {
        var effects = context.roster.activeEffects(for: target)
        let count = effects.count(where: { $0.effect.isRemovableBuff })
        guard count > 0 else { return (0, []) }
        _ = EffectRemoval.removeBuffs(from: &effects, keyword: nil)
        context.roster.setActiveEffects(effects, for: target)
        return (
            count,
            [context.nextEvent(
                kind: .effect,
                effectKind: .purgeApplied,
                actorName: source.name,
                abilityName: name,
                target: target,
                amount: count,
                keyword: .purge,
            )],
        )
    }

    private static func detonate(
        _ keyword: Keyword,
        on target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if keyword == .bleed {
            return CombatTriggerEngine.detonateBleed(on: target, sourceActorID: source.id, in: &context)
        }
        var effects = context.roster.activeEffects(for: target)
        let matching = effects.filter { $0.effect.keyword == keyword }
        effects.removeAll { $0.effect.keyword == keyword }
        context.roster.setActiveEffects(effects, for: target)
        return matching.flatMap { effect in
            DoTDamage.resolveTurnDamage(
                basePotency: effect.effect.potency ?? 0,
                keyword: keyword,
                target: target,
                sourceActorID: source.id,
                in: &context,
            ).events
        }
    }

    private static func damageAfterPurge(
        _ count: Int,
        target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard count > 0 else { return [] }
        return context.activeBoons.flatMap { active -> [ActionEvent] in
            guard !context.boonRuntime.resolvingBoonIDs.contains(active.id),
                  case let .purgeDealsDamage(keyword, amount) = active.boon.effect
            else { return [] }
            guard begin(active, in: &context) else { return [] }
            defer { end(active, in: &context) }
            return dealTypedDamage(count * amount, keyword: keyword, target: target, source: source, in: &context)
        }
    }

    private static func drawCard(_ keyword: Keyword, for actor: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor) else { return [] }
        let beforeCount = context.hand.count + context.handBuffer.count
        guard BattleCardCombatEngine.drawFirstCard(matching: keyword, for: owner, context: &context) != nil else {
            return []
        }
        let afterCount = context.hand.count + context.handBuffer.count
        guard afterCount > beforeCount else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: name,
            target: actor,
            amount: 1,
            keyword: keyword,
        )]
    }

    private static func doubleBleedDuration(on target: Combatant, in context: inout BattleState) {
        var effects = context.roster.activeEffects(for: target)
        for index in effects.indices where effects[index].effect.isBleed {
            effects[index].remainingTurns *= 2
        }
        context.roster.setActiveEffects(effects, for: target)
    }
}
