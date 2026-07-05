import Foundation
import TrinketCore
import TrinketContent

/// Mutation surface passed to rule engines. Same storage as `BattleMutableStore`.
///
/// `tickCount` is advanced by `BattleLoopEngine.advanceOneStep` at the start
/// of each step; callers should not increment it manually.
public typealias BattleEngineContext = BattleMutableStore

public extension BattleEngineContext {
    func modifiers(for combatantID: String) -> CombatModifierProfile {
        build.modifiers(for: combatantID)
    }

    func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    func activeEffects(for combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    mutating func setActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        build.adjustedOutgoingEffect(effect, sourceID: sourceID)
    }

    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += amount + modifiers(for: sourceActorID).goldGainedBonus
    }

    mutating func restoreMana(_ amount: Int, to combatant: Combatant, sourceActorID _: String) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.restoreMana(amount)
        roster.update(runtime)
        return actual
    }

    func mana(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.currentMana ?? 0
    }

    @discardableResult
    mutating func spendMana(_ amount: Int, for combatant: Combatant) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.spendMana(amount)
        roster.update(runtime)
        return actual
    }

    func runtime(for combatant: Combatant) -> CombatantRuntime? {
        roster.runtime(for: combatant)
    }

    mutating func updateRuntime(_ runtime: CombatantRuntime) {
        roster.update(runtime)
    }

    mutating func appendEffect(
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

    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTicks: Int
    ) {
        var effects = activeEffects(for: target)
        effects.insert(
            ActiveEffect(
                id: consumeNextEffectID(),
                effect: effect,
                remainingTicks: remainingTicks,
                sourceActorID: sourceID
            ),
            at: 0
        )
        setActiveEffects(effects, for: target)
    }
}
