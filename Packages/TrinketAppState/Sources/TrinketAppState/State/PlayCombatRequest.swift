import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
struct PlayCombatRequest {
    let origin: PlayBattleOrigin
    let encounter: (combatant: Combatant, level: Int)
    let route: PlayBattleRoute
    let loot: BattleLootPackage?
    let stageRewardsAlreadyClaimed: Bool
    let universalModifiers: [AffixModifier]
    let labyrinthModifiers: [LabyrinthModifierDefinition]

    init(
        origin: PlayBattleOrigin,
        encounter: (combatant: Combatant, level: Int),
        route: PlayBattleRoute,
        loot: BattleLootPackage? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
        labyrinthModifiers: [LabyrinthModifierDefinition] = [],
    ) {
        self.origin = origin
        self.encounter = encounter
        self.route = route
        self.loot = loot
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
        self.universalModifiers = universalModifiers
        self.labyrinthModifiers = labyrinthModifiers
    }
}
