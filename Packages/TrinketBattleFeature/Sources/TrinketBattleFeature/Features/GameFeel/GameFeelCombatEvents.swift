import BattleEngine
import TrinketContent
import TrinketCore

#if DEBUG
enum GameFeelCombatScenario: String, CaseIterable, Identifiable {
    case rapid = "Rapid Hits + Critical"
    case retaliation = "Retaliation + Heal + Block"
    case automatic = "Automatic Chain + Manual Hit"
    case statuses = "Benefits + Setbacks"
    case lethal = "Lethal Hit + Live Feedback"

    var id: String {
        rawValue
    }
}

enum GameFeelCombatEvents {
    static func make(
        _ scenario: GameFeelCombatScenario, index: Int, nextID: inout Int,
        hero: Combatant, enemy: Combatant,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        let actionID = nextID + 1
        func append(
            _ kind: ActionEvent.Kind, effect: ActionEvent.EffectOutcome? = nil,
            amount: Int = 3, keyword: Keyword, target: Combatant,
            critical: Bool = false, origin: ActionEvent.Origin = .direct,
        ) {
            nextID += 1
            events.append(ActionEvent(
                id: nextID, actionID: actionID, kind: kind, effectKind: effect,
                actorID: hero.id, actorName: hero.name, abilityID: "game-feel-fixture",
                abilityName: "Preview", targetID: target.id, targetName: target.name,
                amount: amount, keyword: keyword, isCritical: critical, origin: origin,
            ))
        }
        switch scenario {
        case .rapid, .lethal:
            append(
                .abilityDamage,
                amount: index == 3 ? 18 : 7,
                keyword: .physical,
                target: enemy,
                critical: index == 3,
            )
        case .retaliation:
            append(.abilityDamage, amount: 7, keyword: .physical, target: enemy)
            append(.effect, effect: .thornsTriggered, amount: 2, keyword: .thorns, target: hero)
            append(.effect, effect: .instantHeal, amount: 4, keyword: .health, target: hero)
            append(.effect, effect: .shieldAbsorbed, amount: 3, keyword: .block, target: hero)
        case .automatic:
            append(.ability, amount: 0, keyword: .burn, target: enemy, origin: .automatic)
            append(.abilityDamage, amount: 5, keyword: .burn, target: enemy, origin: .automatic)
            append(.effect, effect: .shieldApplied, amount: 3, keyword: .block, target: hero, origin: .automatic)
        case .statuses:
            append(.effect, effect: .shieldApplied, keyword: .block, target: hero)
            append(.effect, effect: .thornsApplied, keyword: .thorns, target: hero)
            append(.effect, effect: .leechApplied, keyword: .leech, target: hero)
            append(.effect, effect: .recurringDamageApplied, keyword: .poison, target: enemy)
            append(.effect, effect: .recurringDamageApplied, keyword: .bleed, target: enemy)
            append(.effect, effect: .deathsDoorTriggered, amount: 0, keyword: .deathsDoor, target: enemy)
        }
        return events
    }
}

extension BattlePresentationSnapshot {
    init(preview: BattlePresentationSnapshot, enemyHealth: Int) {
        configurationID = preview.configurationID
        hero = preview.hero
        companion = preview.companion
        enemy = BattleCombatantPresentation(
            combatant: preview.enemy.combatant, health: enemyHealth, maxHealth: preview.enemy.maxHealth,
            mana: preview.enemy.mana, maxMana: preview.enemy.maxMana, borderAccentKeyword: preview.enemy.borderAccentKeyword,
        )
        hand = preview.hand
        playableCardIDs = preview.playableCardIDs
        isBattleOver = enemyHealth <= 0
    }
}
#endif
