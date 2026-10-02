import Foundation
import TrinketContent
import TrinketCore

enum DoTMirrorCascade {
    static let maxChainDepth = ReactionScope.maxDoTMirrorChainDepth

    static func resolve(
        keyword: Keyword,
        initialHealthLost: Int,
        target: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard initialHealthLost > 0, context.resolution.depth(.dotMirror) == 0 else { return [] }
        context.resolution.enter(.dotMirror)
        defer { context.resolution.leave(.dotMirror) }
        var events: [ActionEvent] = []
        var currentKeyword = keyword
        var currentAmount = initialHealthLost
        for _ in 0 ..< maxChainDepth {
            guard currentAmount > 0, context.roster.health(for: target) > 0 else { break }
            let triggers = context.modifiers(for: sourceActorID).triggers
            let chance: Double = switch currentKeyword {
            case .burn: triggers.burnProcsBleedChancePercent
            case .bleed: triggers.bleedProcsBurnChancePercent
            default: 0
            }
            guard chance > 0, BattleChance.succeeds(probability: chance, using: &context.rng) else { break }
            let mirrored: Keyword = currentKeyword == .burn ? .bleed : .burn
            let outcome = DoTDamage.resolveDamage(
                basePotency: 1,
                keyword: mirrored,
                target: target,
                sourceActorID: sourceActorID,
                in: &context,
            )
            events.append(contentsOf: outcome.events)
            currentKeyword = mirrored
            currentAmount = outcome.healthLost
        }
        return events
    }
}
