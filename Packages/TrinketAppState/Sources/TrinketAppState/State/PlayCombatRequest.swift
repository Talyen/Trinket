import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
struct PlayCombatRequest {
    let origin: PlayBattleOrigin
    let encounter: ScaledEncounter
    let route: PlayBattleRoute
    let loot: BattleLootResult
    let stageRewardsAlreadyClaimed: Bool
    let universalModifiers: [AffixModifier]
    let labyrinthModifiers: [LabyrinthModifierDefinition]

    init(
        origin: PlayBattleOrigin,
        encounter: ScaledEncounter,
        route: PlayBattleRoute,
        loot: BattleLootResult,
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
