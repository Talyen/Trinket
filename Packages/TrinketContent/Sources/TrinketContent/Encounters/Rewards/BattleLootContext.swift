import TrinketCore

/// Captured loot inputs shared by launch and unsettled completion. Mode policy
/// consumes content values; reading rewards never requires a save store.
public struct BattleLootContext: Equatable, Sendable {
    public let worldSeed: UInt64
    public let ownership: RewardOwnership
    public let astralChanceBonusPercent: Int

    public init(
        worldSeed: UInt64,
        ownership: RewardOwnership = RewardOwnership(),
        astralChanceBonusPercent: Int = 0,
    ) {
        self.worldSeed = worldSeed
        self.ownership = ownership
        self.astralChanceBonusPercent = astralChanceBonusPercent
    }

    public func journey(
        for stage: Stage,
        encounterLevel: Int? = nil,
        enemyIsBoss: Bool? = nil,
        in chapters: [Chapter] = GameContent.chapters,
    ) -> BattleLootResult {
        resolve(
            .journey(stage: stage),
            encounterLevel: encounterLevel ?? EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapters),
            enemyIsBoss: enemyIsBoss ?? isBoss(enemyID: stage.encounter.battleEnemyID),
        )
    }

    public func spire(
        for floor: SpireFloor,
        encounterLevel: Int? = nil,
        modifier: NodeModifierDefinition? = nil,
    ) -> BattleLootResult {
        let selected = modifier ?? GameContent.spireModifier(for: floor, worldSeed: worldSeed)
        let definitions = ownership.modifiers(ids: selected.map { [$0.id] } ?? [])
        let effects = NodeModifierEffects.combining(definitions)
        return resolve(
            .spire(floor: floor, rewardModifier: effects.rewardModifier),
            encounterLevel: encounterLevel ?? EncounterLevelResolver.spireEnemyLevel(for: floor),
            enemyIsBoss: isBoss(enemyID: floor.enemyID),
        )
    }

    public func labyrinth(
        for node: LabyrinthNode,
        effects: NodeModifierEffects,
        encounterLevel: Int? = nil,
    ) -> BattleLootResult? {
        guard node.type.isCombat else { return nil }
        return resolve(
            .labyrinth(node: node, effects: effects),
            encounterLevel: encounterLevel ?? EncounterLevelResolver.labyrinthEnemyLevel(for: node),
            enemyIsBoss: isBoss(enemyID: node.enemyID),
        )
    }

    public func contract(for offer: ContractOffer, encounterLevel: Int) -> BattleLootResult {
        resolve(
            .contract(offerID: offer.id, modifier: ownership.resolved(offer.rewardModifier)),
            encounterLevel: encounterLevel,
            enemyIsBoss: isBoss(enemyID: offer.enemyID),
        )
    }

    public func voyage(node: VoyageNode, encounterLevel: Int) -> BattleLootResult {
        let effects = NodeModifierEffects.combining(ownership.modifiers(ids: node.modifierIDs))
        return resolve(
            .voyage(node: node, effects: effects),
            encounterLevel: encounterLevel,
            enemyIsBoss: node.type == .boss,
        )
    }

    private func resolve(_ request: LootRequest, encounterLevel: Int, enemyIsBoss: Bool) -> BattleLootResult {
        BattleLoot.resolve(
            request, encounterLevel: encounterLevel, enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed, ownership: ownership,
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    private func isBoss(enemyID: String?) -> Bool {
        enemyID.flatMap(GameContent.enemy(matching:))?.isBoss == true
    }
}
