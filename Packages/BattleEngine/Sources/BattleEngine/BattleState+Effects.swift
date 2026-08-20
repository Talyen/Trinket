import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        let profile = modifiers(for: sourceID)
        switch effect {
        case let .shield(keyword, buffer):
            return .shield(
                keyword, buffer + profile.blockGainedBonus
            )
        case let .leech(keyword, percent, durationTurns):
            return .leech(
                keyword,
                percent,
                durationTurns + profile.leechDurationBonus
            )
        default:
            return effect
        }
    }

    // swiftlint:disable:next function_body_length
    mutating func applyBlock(
        _ amount: Int,
        to target: Combatant,
        source: Combatant,
        abilityName: String
    ) -> [ActionEvent] {
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(target, in: self) {
            return []
        }
        let adjusted = adjustedOutgoingEffect(.shield(.block, amount), sourceID: source.id)
        let (keyword, buffer): (Keyword, Int) = if case let .shield(kw, buf) = adjusted {
            (kw, buf)
        } else {
            (.block, amount)
        }
        let applied = DefensePoolEngine.add(
            buffer,
            to: target,
            keyword: keyword,
            sourceActorID: source.id,
            in: &self
        )
        var events = [nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: applied,
            keyword: keyword
        )]
        events.append(contentsOf: CombatTriggerEngine.afterBlockGained(
            applied,
            by: target,
            in: &self
        ))

        // Vital Armor: gain 1 Max Health for every N Block gained this battle (up to +10 Max Health).
        if applied > 0 {
            let triggers = modifiers(for: target.id).triggers
            if triggers.blockGainedMaxHealthEvery > 0 {
                roster.mutateRuntime(for: target) { runtime in
                    let prevBlock = runtime.totalBlockGainedThisCombat
                    let newBlock = prevBlock + applied
                    runtime.totalBlockGainedThisCombat = newBlock
                    let prevBonus = prevBlock / triggers.blockGainedMaxHealthEvery
                    let newBonus = min(10, newBlock / triggers.blockGainedMaxHealthEvery)
                    let gained = newBonus - min(10, prevBonus)
                    if gained > 0 {
                        runtime.talentMaxHealthBonus += gained
                        runtime.currentHealth = min(runtime.maxHealth, runtime.currentHealth + gained)
                    }
                }
            }
            // Shield Bond: whenever the Companion gains Block, the Hero gains equal Block.
            if target.role == .companion,
               triggers.companionBlockSharesToHeroPercent > 0,
               roster.hero.isAlive {
                let share = CombatRounding.scaled(
                    applied,
                    multiplier: min(1, max(0, triggers.companionBlockSharesToHeroPercent))
                )
                if share > 0 {
                    DefensePoolEngine.add(
                        share,
                        to: roster.hero.combatant,
                        keyword: .block,
                        sourceActorID: target.id,
                        in: &self
                    )
                }
            }
        }
        return events
    }

    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTurns: Int
    ) {
        // Fae Ward: block the first debuff applied to the owner each turn.
        if isDebuff(effect),
           modifiers(for: target.id).triggers.blockFirstDebuffPerTurn,
           roster.runtime(for: target)?.faeWardBlockedThisTurn != true {
            roster.mutateRuntime(for: target) { $0.faeWardBlockedThisTurn = true }
            return
        }
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.append(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTurns: remainingTurns,
                    sourceActorID: sourceID
                )
            )
        }
    }

    private func isDebuff(_ effect: Effect) -> Bool {
        switch effect {
        case .burn, .poison, .bleed, .controlMeter, .deathsDoor,
             .damageReductionPercent, .damageReductionFlat, .strengthReduction:
            true
        default:
            false
        }
    }

    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTurns: Int
    ) {
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.insert(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTurns: remainingTurns,
                    sourceActorID: sourceID
                ),
                at: 0
            )
        }
    }
}
