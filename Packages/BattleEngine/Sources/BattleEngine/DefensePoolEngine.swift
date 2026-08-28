import Foundation
import TrinketContent
import TrinketCore

package enum DefensePoolEngine {
    package static func blockPoints(in effects: [ActiveEffect]) -> Int {
        effects.reduce(0) { sum, active in
            if case let .shield(_, buffer) = active.effect {
                return sum + buffer
            }
            return sum
        }
    }

    package struct ShieldPoolReduction {
        package let effects: [ActiveEffect]
        package let keyword: Keyword
        package let absorbed: Int
        package let broken: Bool
    }

    package static func reduce(
        _ amount: Int,
        in effects: [ActiveEffect]
    ) -> ShieldPoolReduction? {
        guard amount > 0,
              let index = effects.firstIndex(where: {
                  if case .shield = $0.effect {
                      return true
                  }
                  return false
              }),
              case let .shield(keyword, buffer) = effects[index].effect,
              buffer > 0
        else { return nil }
        let absorbed = min(amount, buffer)
        var updated = effects
        var broken = false
        if buffer - absorbed <= 0 {
            updated.remove(at: index)
            broken = true
        } else {
            updated[index] = ActiveEffect(
                id: updated[index].id,
                effect: .shield(keyword, buffer - absorbed),
                remainingTurns: 0,
                sourceActorID: updated[index].sourceActorID
            )
        }
        return ShieldPoolReduction(effects: updated, keyword: keyword, absorbed: absorbed, broken: broken)
    }

    package static func effectiveToughnessMitigationPercent(
        for combatant: Combatant
    ) -> Double {
        max(0.0, min(1.0, combatant.primaryStats.toughnessMitigationPercent))
    }

    @discardableResult
    package static func add(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword = .block,
        sourceActorID: String? = nil,
        applyFightPacing: Bool = true,
        in context: inout BattleState
    ) -> Int {
        let pacedAmount = applyFightPacing
            ? (sourceActorID.map { context.paced(amount, sourceActorID: $0) } ?? amount)
            : amount
        guard pacedAmount > 0 else { return 0 }
        var effects = context.roster.activeEffects(for: target)
        if let index = effects.firstIndex(where: {
            if case .shield = $0.effect {
                return true
            }
            return false
        }), case let .shield(existingKeyword, existingBuffer) = effects[index].effect {
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .shield(existingKeyword, existingBuffer + pacedAmount),
                remainingTurns: 0,
                sourceActorID: effects[index].sourceActorID
            )
            context.roster.setActiveEffects(effects, for: target)
            return pacedAmount
        }
        context.appendEffect(
            .shield(keyword, pacedAmount),
            to: target,
            sourceID: sourceActorID ?? target.id,
            remainingTurns: 0
        )
        return pacedAmount
    }

    package static func set(
        _ amount: Int,
        on target: Combatant,
        in context: inout BattleState
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .shield = $0.effect {
                return true
            }
            return false
        }
        context.roster.setActiveEffects(effects, for: target)
        if amount > 0 {
            context.appendEffect(
                .shield(.block, amount),
                to: target,
                sourceID: target.id,
                remainingTurns: 0
            )
        }
    }

    package static func decayBlockAtEndOfRound(
        on target: Combatant,
        in context: inout BattleState
    ) {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return }
        if context.modifiers(for: target.id).triggers.blockRetainsThreeQuarters {
            let retained = min(30, (current * 3) / 4)
            set(retained, on: target, in: &context)
            return
        }
        set(current / 2, on: target, in: &context)
    }

    package static func halveBlock(
        on target: Combatant,
        in context: inout BattleState
    ) -> Bool {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return false }
        set(current / 2, on: target, in: &context)
        return true
    }
}
