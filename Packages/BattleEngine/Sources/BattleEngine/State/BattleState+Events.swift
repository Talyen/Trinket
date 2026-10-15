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
    mutating func collectingEvents(
        _ operation: (inout Self) async throws -> Void,
    ) async rethrows -> [ActionEvent] {
        try await collectingResult(operation).events
    }

    /// Outcomes and command output share emission order, including nested rules.
    /// A standalone operation installs a temporary output even with history disabled.
    mutating func collectingResult<Value>(
        _ operation: (inout Self) async throws -> Value,
    ) async rethrows -> (value: Value, events: [ActionEvent]) {
        let previous = commandOutput
        let output = previous ?? BattleCommandOutput(recordActions: false)
        let start = output.events.count
        commandOutput = output
        defer { commandOutput = previous }
        let value = try await operation(&self)
        return (value, Array(output.events.dropFirst(start)))
    }

    func eventSource(actorID: String?, fallback: Combatant) -> CombatEventSource {
        guard let actorID else { return .init(fallback) }
        return CombatEventSource(actorID: actorID, name: roster.combatant(for: actorID)?.name ?? fallback.name)
    }

    @discardableResult
    mutating func nextEvent(
        kind: ActionEvent.Kind,
        actionID: Int? = nil,
        source: CombatEventSource,
        abilityID: String = "",
        abilityName: String,
        abilityTier: AbilityTier? = nil,
        target: Combatant,
        amount: Int,
        keyword: Keyword,
        appliedEffectSummaries: [String] = [],
        appliedEffects: [Effect] = [],
        stealsGold: Bool = false,
        isCritical: Bool = false,
        origin: ActionEvent.Origin = .automatic,
        isFullyBlocked: Bool = false,
    ) -> ActionEvent {
        nextEventID += 1
        let event = ActionEvent(
            id: nextEventID,
            actionID: actionID ?? (actionCount + 1),
            kind: kind,
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
            appliedEffects: appliedEffects,
            stealsGold: stealsGold,
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
        commandOutput?.append(event)
        return event
    }

    mutating func appendMilestone(_ milestone: ActionEvent.Milestone) -> ActionEvent {
        nextEvent(
            kind: .milestone(milestone),
            source: .none,
            abilityName: "",
            target: enemy,
            amount: 0,
            keyword: .physical,
        )
    }

    mutating func appendDefeatMilestonesIfNeeded() async {
        if roster.isEnemyDefeated, !hasLoggedDefeat {
            hasLoggedDefeat = true
            _ = appendMilestone(.enemyDefeated)
            await CombatTriggerEngine.afterEnemyDefeated(in: &self)
            if !roster.isPartyDefeated {
                await CombatTriggerEngine.afterVictory(in: &self)
            }
        }
        if roster.isPartyDefeated, !hasLoggedPartyDefeat {
            hasLoggedPartyDefeat = true
            _ = appendMilestone(.partyDefeated)
        }
    }
}
