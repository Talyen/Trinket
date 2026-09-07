import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func afterDodge(
        by actor: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.uniques.reactionDepth == 0,
              let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster[owner].isAlive
        else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.dodgeNextHitPoisonAndBleedPercent > 0 {
            context.uniques.owners[owner, default: .init()].viperReady = true
        }
        var events: [ActionEvent] = []
        if triggers.dodgeDrawPoisonAndReadyCritical {
            context.uniques.owners[owner, default: .init()].wildheartReady = true
            if BattleCardCombatEngine.drawFirstCard(matching: .poison, for: owner, context: &context) != nil {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: actor.name,
                    abilityName: "Wildheart’s Favor",
                    target: actor,
                    amount: 1,
                    keyword: .poison,
                ))
            }
        }
        guard triggers.dodgeSpendsHalfBlockAsPhysical else { return events }
        let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
        let spent = block / 2
        guard spent > 0 else { return events }
        DefensePoolEngine.set(block - spent, on: actor, in: &context)
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .shieldHalved,
            actorName: actor.name,
            abilityName: "Laughing Guard",
            target: actor,
            amount: spent,
            keyword: .block,
        ))
        guard let attackerID, let attacker = context.roster.combatant(for: attackerID), attacker.isAlive else { return events }
        context.uniques.reactionDepth += 1
        defer { context.uniques.reactionDepth -= 1 }
        events.append(contentsOf: repeatHit(
            DamageRequest(
                amount: spent,
                target: attacker.combatant,
                keyword: .physical,
                sourceActorID: actor.id,
                options: DamageOptions(isRetaliation: true, causedByDodge: true),
            ),
            actor: actor,
            name: "Laughing Guard",
            in: &context,
        ))
        return events
    }
}
