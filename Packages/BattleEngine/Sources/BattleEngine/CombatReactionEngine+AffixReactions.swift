import Foundation
import TrinketContent
import TrinketCore

package extension CombatReactionEngine {
    static func afterCriticalHit(
        to enemy: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard source.role != .enemy else { return [] }
        let profile = context.modifiers(for: source.id)
        var events = applyPurge(
            to: enemy,
            source: source,
            abilityName: "Unmaking",
            count: profile.triggers.criticalPurgeCount,
            purgeAll: profile.triggers.criticalPurgeAll,
            in: &context
        )

        if profile.triggers.criticalGoldFlat > 0 {
            events.append(grantGold(
                profile.triggers.criticalGoldFlat,
                to: source,
                abilityName: profile.traitDisplayName ?? "Cutpurse",
                in: &context
            ))
        }

        return events
    }

    static func afterGainMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let amount = context.modifiers(for: actor.id).triggers.gainManaBlockFlat
        guard amount > 0 else { return [] }
        return applyBlock(
            amount: amount,
            to: actor,
            source: actor,
            abilityName: "Arcane Ward",
            in: &context
        )
    }

    static func afterLeech(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        var events: [ActionEvent] = []

        if profile.triggers.leechRestoreManaFlat > 0 {
            let restored = context.restoreMana(
                context.paced(profile.triggers.leechRestoreManaFlat, sourceActorID: actor.id),
                to: actor,
                sourceActorID: actor.id
            )
            if restored > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: "Siphoning",
                    target: actor,
                    amount: restored,
                    keyword: .mana
                ))
                events.append(contentsOf: afterGainMana(by: actor, in: &context))
            }
        }

        if profile.triggers.leechGoldFlat > 0 {
            events.append(grantGold(
                profile.triggers.leechGoldFlat,
                to: actor,
                abilityName: "Blood Price",
                in: &context
            ))
        }

        return events
    }

    static func afterEnemyDefeated(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        if context.roster.hero.isAlive {
            let hero = context.roster.hero.combatant
            let amount = context.heroModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(grantGold(amount, to: hero, abilityName: "Bounty", in: &context))
            }
        }

        if context.roster.companion.isAlive {
            let companion = context.roster.companion.combatant
            let amount = context.companionModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(grantGold(amount, to: companion, abilityName: "Bounty", in: &context))
            }
        }

        return events
    }

    static func applySidestepHeal(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeHealFlat > 0 else { return [] }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.triggers.dodgeHealFlat,
                target: combatant,
                sourceActorID: combatant.id,
                logAs: .instantHeal(
                    actorName: combatant.name,
                    abilityName: "Sidestep",
                    keyword: .health,
                    displayAmount: profile.triggers.dodgeHealFlat
                )
            ),
            in: &context
        ).events
    }

    static func applyWhiplashStun(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeDealStunFlat > 0, context.roster.enemy.isAlive else { return [] }
        // Avoid nesting a full damage pipeline inside DodgeGate (stack overflow in
        // long balance sims). Apply authored Stun damage as a direct health hit.
        let enemy = context.roster.enemy.combatant
        let amount = profile.triggers.dodgeDealStunFlat
        let lost = context.roster.runtime(for: enemy).map { runtime -> Int in
            var copy = runtime
            let dealt = copy.takeRawDamage(amount)
            context.roster.update(copy)
            return dealt
        } ?? 0
        guard lost > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: nil,
            actorName: combatant.name,
            abilityName: "Whiplash",
            target: enemy,
            amount: lost,
            keyword: .stun
        )]
    }

    /// Grants `amount` Gold to the party pool and returns the `resourceGain` event.
    static func grantGold(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        in context: inout BattleState
    ) -> ActionEvent {
        let granted = context.goldGranted(for: amount, sourceActorID: combatant.id)
        context.addGold(amount, sourceActorID: combatant.id)
        return context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: combatant.name,
            abilityName: abilityName,
            target: combatant,
            amount: granted,
            keyword: .gold
        )
    }
}
