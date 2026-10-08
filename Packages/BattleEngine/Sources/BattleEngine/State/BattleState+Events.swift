import TrinketContent
import TrinketCore

/// Event attribution travels with its display text; names never establish identity.
package struct CombatEventSource: Equatable, Hashable, Sendable {
    let actorID: String
    let actorName: String

    init(_ combatant: Combatant) {
        actorID = combatant.id
        actorName = combatant.name
    }

    init(_ runtime: CombatantRuntime) {
        self.init(runtime.combatant)
    }

    /// Periodic/environmental captions can retain an owner without naming them.
    init(actorID: String?, name: String) {
        self.actorID = actorID ?? ""
        actorName = name
    }

    static let none = Self(actorID: nil, name: "")
}

package extension BattleState {
    func eventSource(actorID: String?, fallback: Combatant) -> CombatEventSource {
        guard let actorID else { return .init(fallback) }
        return CombatEventSource(actorID: actorID, name: roster.combatant(for: actorID)?.name ?? fallback.name)
    }

    mutating func nextEvent(
        kind: ActionEvent.Kind,
        actionID: Int? = nil,
        effectKind: ActionEvent.EffectOutcome? = nil,
        source: CombatEventSource,
        abilityID: String = "",
        abilityName: String,
        abilityTier: AbilityTier? = nil,
        target: Combatant,
        amount: Int,
        keyword: Keyword,
        appliedEffectSummaries: [String] = [],
        milestone: ActionEvent.Milestone? = nil,
        isCritical: Bool = false,
        origin: ActionEvent.Origin = .automatic,
        isFullyBlocked: Bool = false,
    ) -> ActionEvent {
        nextEventID += 1
        let event = ActionEvent(
            id: nextEventID,
            actionID: actionID ?? (actionCount + 1),
            kind: kind,
            effectKind: effectKind,
            actorID: source.actorID,
            actorName: source.actorName,
            abilityID: abilityID,
            abilityName: abilityName,
            abilityTier: abilityTier,
            targetID: target.id,
            targetName: target.name,
            amount: amount,
            keyword: keyword,
            appliedEffectSummaries: appliedEffectSummaries,
            milestone: milestone,
            isCritical: isCritical,
            feedbackGroupID: resolution.feedbackGroupID ?? nextEventID,
            origin: origin == .direct && !resolution.isAutomaticPlay
                ? .direct
                : (resolution.isAdvancingEffects ? .periodic : .automatic),
            isFullyBlocked: isFullyBlocked,
        )
        if tracksEvents {
            events.append(event)
        }
        cardPlayRecording?.append(event)
        return event
    }

    mutating func appendMilestone(_ milestone: ActionEvent.Milestone) -> ActionEvent {
        nextEvent(
            kind: .milestone,
            source: .none,
            abilityName: "",
            target: enemy,
            amount: 0,
            keyword: .physical,
            milestone: milestone,
        )
    }

    mutating func appendDefeatMilestonesIfNeeded() async -> [ActionEvent] {
        var milestones: [ActionEvent] = []
        if roster.isEnemyDefeated, !hasLoggedDefeat {
            hasLoggedDefeat = true
            milestones.append(appendMilestone(.enemyDefeated))
            await milestones.append(contentsOf: CombatTriggerEngine.afterEnemyDefeated(in: &self))
            if !roster.isPartyDefeated {
                await milestones.append(contentsOf: CombatTriggerEngine.afterVictory(in: &self))
            }
        }
        if roster.isPartyDefeated, !hasLoggedPartyDefeat {
            hasLoggedPartyDefeat = true
            milestones.append(appendMilestone(.partyDefeated))
        }
        return milestones
    }
}
