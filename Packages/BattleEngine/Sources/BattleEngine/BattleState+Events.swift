import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func nextEvent(
        kind: ActionEvent.Kind,
        actionID: Int? = nil,
        effectKind: ActionEvent.EffectKind? = nil,
        actorID: String = "",
        actorName: String,
        abilityID: String = "",
        abilityName: String,
        abilityTier: AbilityTier? = nil,
        target: Combatant,
        amount: Int,
        keyword: Keyword,
        appliedEffectSummaries: [String] = [],
        milestone: ActionEvent.Milestone? = nil,
        isCritical: Bool = false
    ) -> ActionEvent {
        nextEventID += 1
        let event = ActionEvent(
            id: nextEventID,
            actionID: actionID ?? (actionCount + 1),
            kind: kind,
            effectKind: effectKind,
            actorID: actorID,
            actorName: actorName,
            abilityID: abilityID,
            abilityName: abilityName,
            abilityTier: abilityTier,
            targetID: target.id,
            targetName: target.name,
            amount: amount,
            keyword: keyword,
            appliedEffectSummaries: appliedEffectSummaries,
            milestone: milestone,
            isCritical: isCritical
        )
        if tracksEvents {
            events.append(event)
        }
        return event
    }

    mutating func appendMilestone(_ milestone: ActionEvent.Milestone, matchup: BattleMatchup) -> ActionEvent {
        nextEvent(
            kind: .milestone,
            actorName: "",
            abilityName: "",
            target: matchup.enemy,
            amount: 0,
            keyword: .physical,
            milestone: milestone
        )
    }

    mutating func appendDefeatMilestonesIfNeeded(matchup: BattleMatchup) -> [ActionEvent] {
        var milestones: [ActionEvent] = []
        if roster.isEnemyDefeated, !hasLoggedDefeat {
            hasLoggedDefeat = true
            milestones.append(appendMilestone(.enemyDefeated, matchup: matchup))
            milestones.append(contentsOf: CombatTriggerEngine.afterEnemyDefeated(in: &self))
        }
        if roster.isPartyDefeated, !hasLoggedPartyDefeat {
            hasLoggedPartyDefeat = true
            milestones.append(appendMilestone(.partyDefeated, matchup: matchup))
        }
        return milestones
    }
}
