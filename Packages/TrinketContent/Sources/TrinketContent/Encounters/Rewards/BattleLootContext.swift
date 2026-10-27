import TrinketCore

/// Captured loot inputs shared by launch and unsettled completion. Mode policy
/// consumes content values; reading rewards never requires a save store.
public struct BattleLootContext: Equatable, Sendable {
    public let wishedTemplateID: String?
    public let partyBias: PartyLootBias
    public let worldSeed: UInt64
    public let ownership: RewardOwnership
    public let astralChanceBonusPercent: Int
    public let claimedJourneyRewardStageIDs: Set<String>

    public init(
        worldSeed: UInt64,
        ownership: RewardOwnership = RewardOwnership(),
        astralChanceBonusPercent: Int = 0,
        claimedJourneyRewardStageIDs: Set<String> = [],
        wishedTemplateID: String? = nil,
        partyBias: PartyLootBias = PartyLootBias(),
    ) {
        self.partyBias = partyBias
        self.worldSeed = worldSeed
        self.wishedTemplateID = wishedTemplateID
        self.ownership = ownership
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.claimedJourneyRewardStageIDs = claimedJourneyRewardStageIDs
    }

    public func journey(
        for stage: Stage,
        encounterLevel: Int? = nil,
        enemyIsBoss: Bool? = nil,
        in chapters: [Chapter] = GameContent.chapters,
    ) -> BattleLootResult {
        var request = LootRequest.journey(stage: stage)
        if !claimedJourneyRewardStageIDs.contains(stage.id) {
            let openingBoss = chapters.lazy.flatMap(\.stages).first {
                Self.bossEnemyIDs.contains($0.encounter.battleEnemyID ?? "")
            }
            request.guaranteesTrinket = stage.id == openingBoss?.id
        } else {
            request.guaranteesTrinket = false
        }
        return resolve(
            request,
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
        let enemyIsBoss = isBoss(enemyID: floor.enemyID)
        let definitions = ownership.modifiers(ids: selected.map { [$0.id] } ?? [], enemyIsBoss: enemyIsBoss)
        let effects = NodeModifierEffects.combining(definitions)
        return resolve(
            .spire(floor: floor, rewardModifier: effects.rewardModifier),
            encounterLevel: encounterLevel ?? EncounterLevelResolver.spireEnemyLevel(for: floor),
            enemyIsBoss: enemyIsBoss,
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
        let enemyIsBoss = isBoss(enemyID: offer.enemyID)
        return resolve(
            .contract(offerID: offer.id, modifier: ownership.resolved(offer.rewardModifier, enemyIsBoss: enemyIsBoss)),
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
        )
    }

    public func voyage(node: VoyageNode, encounterLevel: Int) -> BattleLootResult {
        let effects = NodeModifierEffects.combining(ownership.modifiers(ids: node.modifierIDs, enemyIsBoss: node.type == .boss))
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
            wishedTemplateID: wishedTemplateID, partyBias: partyBias,
        )
    }

    private func isBoss(enemyID: String?) -> Bool {
        enemyID.flatMap(GameContent.enemy(matching:))?.isBoss == true
    }

    private static let bossEnemyIDs: Set<String> = Set(GameContent.bossEnemies.lazy.map(\.id))
}
