import Foundation
import TrinketCore
import TrinketContent

/// Narrow mutation context passed to effect handlers. Owns the roster slice,
/// RNG, ID counters, and event stream for one handler dispatch.
public struct BattleEngineContext {
    public var roster: BattleRoster
    public var rng: SeededRandomNumberGenerator
    public var nextEffectID: Int
    public var nextEventID: Int
    public var events: [ActionEvent]
    public var gold: Int
    public let build: BattleCombatBuild

    public init(
        roster: BattleRoster,
        rng: SeededRandomNumberGenerator,
        nextEffectID: Int,
        nextEventID: Int,
        events: [ActionEvent],
        gold: Int,
        build: BattleCombatBuild
    ) {
        self.roster = roster
        self.rng = rng
        self.nextEffectID = nextEffectID
        self.nextEventID = nextEventID
        self.events = events
        self.gold = gold
        self.build = build
    }

    public func modifiers(for combatantID: String) -> CombatModifierProfile {
        build.modifiers(for: combatantID)
    }

    public func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    public func activeEffects(for combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    public mutating func setActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    public mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    public func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        build.adjustedOutgoingEffect(effect, sourceID: sourceID)
    }

    public mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += amount + modifiers(for: sourceActorID).goldGainedBonus
    }

    public mutating func restoreMana(_ amount: Int, to combatant: Combatant, sourceActorID _: String) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.restoreMana(amount)
        roster.update(runtime)
        return actual
    }

    public func runtime(for combatant: Combatant) -> CombatantRuntime {
        guard let runtime = roster.runtime(for: combatant) else {
            preconditionFailure("Unknown combatant id \(combatant.id)")
        }
        return runtime
    }

    public mutating func updateRuntime(_ runtime: CombatantRuntime) {
        roster.update(runtime)
    }

    public mutating func nextEvent(
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind? = nil,
        actorName: String,
        abilityName: String,
        target: Combatant,
        amount: Int,
        keyword: Keyword,
        appliedEffectSummaries: [String] = [],
        milestone: ActionEvent.Milestone? = nil
    ) -> ActionEvent {
        nextEventID += 1
        let event = ActionEvent(
            id: nextEventID,
            kind: kind,
            effectKind: effectKind,
            actorName: actorName,
            abilityName: abilityName,
            targetID: target.id,
            targetName: target.name,
            amount: amount,
            keyword: keyword,
            appliedEffectSummaries: appliedEffectSummaries,
            milestone: milestone
        )
        events.append(event)
        return event
    }

    public mutating func logDoTDamage(
        _ result: (healthLost: Int, events: [ActionEvent]),
        keyword: Keyword,
        target: Combatant
    ) -> [ActionEvent] {
        var collected = result.events
        guard result.healthLost > 0 else { return collected }

        let event = nextEvent(
            kind: .status,
            effectKind: nil,
            actorName: keyword.rawValue,
            abilityName: keyword.rawValue,
            target: target,
            amount: result.healthLost,
            keyword: keyword
        )
        collected.append(event)
        return collected
    }

    public mutating func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        CombatPipeline.applyDamage(
            amount,
            to: combatant,
            damageKeyword: damageKeyword,
            sourceActorID: sourceActorID,
            applyStatBonus: applyStatBonus,
            applyItemBonus: applyItemBonus,
            applyDodge: applyDodge,
            in: &self
        )
    }

    public mutating func applyHeal(_ amount: Int, to combatant: Combatant, sourceActorID: String? = nil) {
        CombatPipeline.applyHeal(amount, to: combatant, sourceActorID: sourceActorID, in: &self)
    }

    public mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        CombatPipeline.applyLeechFromDamage(damage, sourceActorID: sourceActorID, in: &self)
    }

    public mutating func applyDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> (healthLost: Int, events: [ActionEvent]) {
        CombatPipeline.applyDoTDamage(
            amount,
            keyword: keyword,
            to: combatant,
            sourceActorID: sourceActorID,
            in: &self
        )
    }

    public mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        DoTApplicator.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            dealImmediateDamage: dealImmediateDamage,
            in: &self
        )
    }

    public mutating func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        DoTApplicator.applyBleed(
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            dealImmediateDamage: dealImmediateDamage,
            in: &self
        )
    }
}

public extension BattleEngineContext {
    public mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTicks: Int
    ) {
        var effects = activeEffects(for: target)
        effects.append(
            ActiveEffect(
                id: consumeNextEffectID(),
                effect: effect,
                remainingTicks: remainingTicks,
                sourceActorID: sourceID
            )
        )
        setActiveEffects(effects, for: target)
    }
}
