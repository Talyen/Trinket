import TrinketContent
import TrinketCore

enum DecayingDoT {
    case burn, poison

    init?(effect: Effect) {
        switch effect {
        case .burn: self = .burn
        case .poison: self = .poison
        default: return nil
        }
    }

    var keyword: Keyword {
        switch self {
        case .burn: .burn
        case .poison: .poison
        }
    }

    var kind: EffectKind {
        switch self {
        case .burn: .burn
        case .poison: .poison
        }
    }

    func effect(potency: Int) -> Effect {
        switch self {
        case .burn: .burn(potency)
        case .poison: .poison(potency)
        }
    }
}

/// Captures the original stack owner's rules before damage reactions mutate the battle.
struct DecayingDoTProgression {
    let type: DecayingDoT
    let ticksPerTurn: Int
    private let slowPercent: Double
    private let preventDecayChance: Double
    private let increaseChance: Double

    init(type: DecayingDoT, sourceActorID: String?, target: Combatant, in context: BattleState) {
        self.type = type
        let triggers = sourceActorID.map { context.modifiers(for: $0).triggers }
        switch type {
        case .burn:
            slowPercent = (triggers?.burnDecaySlowPercent ?? 0)
                + (context.roster.hasAffliction(.bleed, on: target)
                    ? (triggers?.burnDecaySlowVsBleedingPercent ?? 0) : 0)
            preventDecayChance = triggers?.burnPreventDecayChancePercent ?? 0
            increaseChance = triggers?.burnIncreaseChancePercent ?? 0
            ticksPerTurn = triggers?.burnTicksTwicePerTurn == true ? 2 : 1
        case .poison:
            slowPercent = triggers?.poisonDecaySlowPercent ?? 0
            preventDecayChance = triggers?.poisonPreventDecayChancePercent ?? 0
            increaseChance = triggers?.poisonDecayIncreaseChance ?? 0
            ticksPerTurn = 1
        }
    }

    func decayedPotency(from potency: Int) -> Int {
        type.effect(potency: potency).potencyAfterTurn(
            burnDecaySlowPercent: slowPercent,
            poisonDecaySlowPercent: slowPercent,
        )
    }

    /// Preservation wins over growth. Only live turns roll; detonations use decay alone.
    func turnPotency(from potency: Int, using rng: inout some RandomNumberGenerator) -> Int {
        if BattleChance.succeeds(probability: preventDecayChance, using: &rng) {
            return potency
        }
        if BattleChance.succeeds(probability: increaseChance, using: &rng) {
            return potency + 1
        }
        return decayedPotency(from: potency)
    }
}

enum DecayingDoTDetonation {
    /// Callers commit stack removal and own recursion scope before entering this executor.
    static func resolve(
        _ active: ActiveEffect,
        factor: Int,
        target: Combatant,
        sourceActorID: String,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let type = DecayingDoT(effect: active.effect) else { return [] }
        let progression = DecayingDoTProgression(
            type: type, sourceActorID: active.sourceActorID, target: target, in: context,
        )
        var potency = active.effect.potency ?? 0
        var events: [ActionEvent] = []
        while context.roster.health(for: target) > 0 {
            potency = progression.decayedPotency(from: potency)
            guard potency > 0 else { break }
            for _ in 0 ..< progression.ticksPerTurn where context.roster.health(for: target) > 0 {
                events.append(contentsOf: DoTDamage.resolveDamage(
                    basePotency: potency * factor,
                    keyword: type.keyword,
                    target: target,
                    sourceActorID: sourceActorID,
                    provenance: provenance,
                    operation: .resolvedPeriodic,
                    in: &context,
                ).events)
            }
        }
        return events
    }
}
