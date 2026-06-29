import SwiftUI

@Observable
final class BattleSession {
    var activeBattle: ActiveBattleConfiguration?
    var isPaused = false

    func start(hero: Combatant, pet: Combatant, rosterStore: PlayerRosterStore, inventoryStore: PlayerInventoryStore, preset: BattlePreset = .fresh) {
        let battle: ActiveBattleConfiguration
        switch preset {
        case .oneShot:
            let result = BattleSimulator.runToHealth(targetHealth: 1, hero: hero, pet: pet)
            battle = ActiveBattleConfiguration(
                hero: result.hero,
                pet: result.pet,
                heroProgression: rosterStore.progression(for: hero),
                petProgression: rosterStore.progression(for: pet),
                heroEquipmentLoadout: rosterStore.equipmentLoadout(for: hero),
                petEquipmentLoadout: rosterStore.equipmentLoadout(for: pet),
                inventoryState: inventoryStore.current
            )
        case .fresh:
            battle = ActiveBattleConfiguration(
                hero: hero,
                pet: pet,
                heroProgression: rosterStore.progression(for: hero),
                petProgression: rosterStore.progression(for: pet),
                heroEquipmentLoadout: rosterStore.equipmentLoadout(for: hero),
                petEquipmentLoadout: rosterStore.equipmentLoadout(for: pet),
                inventoryState: inventoryStore.current
            )
        }
        activeBattle = battle
        isPaused = false
    }

    func end() {
        activeBattle = nil
        isPaused = false
    }
}

enum BattlePreset: String {
    case fresh
    case oneShot
}

extension BattleSimulator {
    static func runToHealth(targetHealth: Int, hero: Combatant, pet: Combatant, enemy: Combatant = .trainingSlime, maxTicks: Int = 100) -> BattleState {
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)
        while !battle.isEnemyDefeated, battle.tickCount < maxTicks, battle.enemyHealth > targetHealth {
            _ = battle.performNextAction()
        }
        return battle
    }
}
