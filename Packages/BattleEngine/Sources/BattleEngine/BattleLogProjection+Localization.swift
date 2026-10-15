import Foundation
import TrinketContent
import TrinketCore

extension BattleLogProjection {
    static func localizedLine(for event: ActionEvent, damage: [ActionEvent], locale: Locale) -> String {
        let actor = ContentCopy.resource(event.actorName)
        let target = ContentCopy.resource(event.targetName)
        let ability = ContentCopy.resource(event.abilityName)
        let keyword = event.keyword.nameResource
        let resources: [LocalizedStringResource]
        switch event.kind {
        case .ability:
            let (reported, healthCost) = damageReport(for: event, damage: damage)
            var parts = [L10n.log_use(actor, ability)]
            parts += reported.map {
                L10n.log_damage(actor, $0.amount, $0.keyword.nameResource, ContentCopy.resource($0.targetName), ability)
            }
            if healthCost > 0 {
                parts.append(L10n.log_cost(actor, healthCost))
            }
            let effects = localizedEffects(event, locale: locale)
            if !effects.isEmpty {
                parts.append(L10n.log_applies(actor, BattleCopy.list(effects)))
            }
            resources = parts
        case .abilityDamage:
            resources = [L10n.log_damage(actor, event.amount, keyword, target, ability)]
        case .status:
            resources = [L10n.log_status(target, event.amount, keyword)]
        case let .milestone(milestone):
            switch milestone {
            case let .battleStarted(hero, companion):
                resources = [L10n.log_start(ContentCopy.resource(hero), ContentCopy.resource(companion), target)]
            case .enemyDefeated: resources = [L10n.log_defeated(target)]
            case .partyDefeated: resources = [L10n.log_party_defeated(target)]
            }
        case let .effect(outcome):
            switch outcome {
            case .deathsDoorTriggered: resources = [L10n.log_door(target)]
            case .deathsDoorExpired: resources = [L10n.log_door_fades(target)]
            case .controlTriggered: resources = [L10n.log_control(
                    target,
                    ContentCopy.resource(event.keyword.statusAlias ?? event.keyword.rawValue),
                )]
            case .shieldApplied: resources = [L10n.log_block(target, event.amount, ability)]
            case .instantHeal, .leechHeal: resources = [L10n.log_heal(target, event.amount, ability)]
            case .thornsTriggered:
                resources = event.abilityName.isEmpty ? [L10n.log_reflect(actor, event.amount, keyword, target)]
                    : [L10n.log_damage(actor, event.amount, keyword, target, ability)]
            case .cleanseApplied: resources = [L10n.log_cleanse(target, keyword, ability)]
            case .purgeApplied: resources = [L10n.log_purge(target, keyword, ability)]
            case .blockStripped: resources = [L10n.log_strip(actor, event.amount, target, ability)]
            case .damageReduced: resources = [L10n.log_reduced(actor, event.amount, ability)]
            case .hemorrhageTriggered: resources = [L10n.log_hemorrhage(target, event.amount)]
            default: resources = []
            }
        }
        return resources.map { LocalizedGameText($0, locale: locale).text }.joined(separator: "\n")
    }

    private static func localizedEffects(_ event: ActionEvent, locale: Locale) -> [LocalizedStringResource] {
        event.appliedEffects.map { effect -> LocalizedStringResource in
            if case let .resourceGain(.gold, amount) = effect {
                return event.stealsGold ? L10n.log_steal_gold(amount) : L10n.log_gain_gold(amount)
            }
            return LocalizedStringResource(String.LocalizationValue(stringLiteral: EffectPresentation.localizedDescription(
                for: effect,
                locale: locale,
            ).markedText))
        }
    }
}
