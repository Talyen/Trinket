import BattleEngine
import TrinketCore

enum BattleCardCueRecipes {
    static func recipients(for assessment: BattleCardAssessment) -> [String: BattleRecipientCue] {
        var recipients: [String: BattleRecipientCue] = [:]
        for target in assessment.targets {
            let cue = recipe(for: target.intent)
            if let previous = recipients[target.combatantID], previous.kind.rawValue <= cue.kind.rawValue {
                continue
            }
            recipients[target.combatantID] = cue
        }
        for resource in assessment.resources {
            let cue = BattleRecipientCue(kind: resource.keyword == .block ? .protect : .prepare, keyword: resource.keyword)
            if let previous = recipients[resource.combatantID], previous.kind.rawValue <= cue.kind.rawValue {
                continue
            }
            recipients[resource.combatantID] = cue
        }
        recipients[assessment.actorID] = recipients[assessment.actorID] ?? .init(kind: .prepare, keyword: nil)
        return recipients
    }

    static func recipe(for intent: BattleCardAssessment.Intent) -> BattleRecipientCue {
        switch intent {
        case let .damage(keyword):
            .init(kind: .attack, keyword: keyword)
        case let .effect(effect):
            .init(kind: kind(for: effect), keyword: effect.keyword)
        }
    }

    private static func kind(for effect: Effect) -> BattleCardCueKind {
        switch effect {
        case .cleanse, .cleanseRandom, .purge, .purgeRandom, .cleanseHealPerDebuff, .panacea:
            .cleanse
        case .instantHeal, .revive, .resourceGain(.mana, _):
            .restore
        case .shield, .thorns, .deathsDoor, .evadeNextHit, .freezeNextAttacker, .onHitDamage,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold,
             .damageReductionPercent, .damageReductionFlat:
            .protect
        case .burn, .poison, .bleed, .controlMeter, .marked, .halveShield, .multiplyDoT, .detonateDoT,
             .recurringDamage, .healingReductionPercent, .hemorrhage:
            .attack
        case .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride, .nextHolyStrike,
             .nextStrikeDouble, .nextBurnBonus, .maximumManaBonus, .nextStrikeCritical, .avatar:
            .prepare
        case .drawCards, .drawAndPlayCards, .resourceGain:
            .gain
        }
    }
}
