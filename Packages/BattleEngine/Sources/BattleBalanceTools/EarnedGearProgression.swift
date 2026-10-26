import TrinketContent
import TrinketCore

public enum ProgressionEquipmentModel: String, Codable, Sendable {
    case earned
    case tier

    public var description: String {
        switch self {
        case .earned: "Retained victory loot; fixed abilities and cumulative legal talents"
        case .tier: "Legacy idealized tier gear; regenerated abilities, gear and talents each battle"
        }
    }
}

/// One run owns its selections and physical inventory. No quality band replaces
/// this state on leveling, and no battle-preview seed can reroll its gear.
final class EarnedGearProgression {
    let hero: Combatant
    let companion: Combatant
    let heroLoadout: AbilityLoadout
    let companionLoadout: AbilityLoadout
    private let worldSeed: UInt64
    private var random: SeededRandomNumberGenerator
    private(set) var inventory: [InventoryItem] = []
    private(set) var equipment: [String: EquipmentLoadout] = [:]
    private(set) var talents: [String: Set<String>] = [:]
    private(set) var claimedSteps: Set<String> = []
    private var claimedJourneyStages: Set<String> = []

    init(hero: Combatant, companion: Combatant, worldSeed: UInt64) {
        self.hero = hero
        self.companion = companion
        self.worldSeed = worldSeed
        random = SeededRandomNumberGenerator(seed: worldSeed)
        let loadouts = SimulationMatchupBuilder.samplePartyLoadouts(hero: hero, companion: companion, using: &random)
        heroLoadout = loadouts.hero
        companionLoadout = loadouts.companion
    }

    func invest(state: PlayerProgressionState) {
        for (base, loadout, level) in [(hero, heroLoadout, state.heroLevel), (companion, companionLoadout, state.companionLevel)] {
            let owner = base.withAbilityLoadout(loadout, fillsMissingSelections: false)
            let reserved = Set(equipment.filter { $0.key != owner.id }.values.flatMap(\.itemIDsBySlot.values))
            var worn = equipment[owner.id] ?? EquipmentLoadout()
            while let upgrade = SimulationEquipmentPolicy.nextUpgrade(
                for: owner, inventory: inventory, loadout: worn, reservedItemIDs: reserved,
            ) {
                guard let item = inventory.first(where: { $0.id == upgrade.itemID }) else { break }
                if let slot = upgrade.unequipFirst {
                    worn.unequip(slot)
                }
                worn.equip(item, in: upgrade.slot, inventory: inventory)
            }
            equipment[owner.id] = worn
            var unlocked = talents[owner.id] ?? []
            let budget = CombatantProgression.at(level: level).totalTalentPoints
            let config = CombatantTalentCatalog.config(for: owner.id)
            while unlocked.count < budget {
                let candidates = config.trees.flatMap { tree in
                    tree.nodes.filter { tree.canUnlock(node: $0, unlockedNodeIDs: unlocked, availablePoints: 1) }
                }
                guard let node = candidates.randomElement(using: &random) else { break }
                unlocked.insert(node.id)
            }
            talents[owner.id] = unlocked
        }
    }

    func awardVictory(step: ModeProgressionStep, encounterLevel: Int) {
        guard claimedSteps.insert(step.id).inserted else { return }
        let ownership = RewardOwnership(
            ownedTrinketIDs: Set(inventory.filter(\.isTrinket).map(\.templateID)),
            ownedUniqueIDs: Set(inventory.filter { $0.rarity == .unique }.map(\.templateID)),
        )
        let roster = PlayerRosterState(
            activeHeroID: hero.id, activeCompanionID: companion.id,
            unlockedHeroIDs: [hero.id], unlockedCompanionIDs: [companion.id],
            abilityLoadouts: [hero.id: heroLoadout, companion.id: companionLoadout],
            progressions: [:], equipmentLoadouts: equipment,
        )
        let context = BattleLootContext(
            worldSeed: worldSeed, ownership: ownership,
            claimedJourneyRewardStageIDs: claimedJourneyStages, partyBias: PartyLootBias(roster: roster),
        )
        let loot: BattleLootResult
        switch step.mode {
        case .campaign:
            if let stage = GameContent.chapter(id: step.containerID)?.stages.first(where: { $0.stageNumber == step.stepIndex }) {
                loot = context.journey(for: stage, encounterLevel: encounterLevel, enemyIsBoss: step.isBoss)
                claimedJourneyStages.insert(stage.id)
            } else {
                loot = resolveGeneric(step: step, encounterLevel: encounterLevel, context: context)
            }
        case .spire:
            if let floor = GameContent.spireFloor(spireID: SpireID(step.containerID), floor: step.stepIndex) {
                loot = context.spire(for: floor, encounterLevel: encounterLevel)
            } else {
                loot = resolveGeneric(step: step, encounterLevel: encounterLevel, context: context)
            }
        case .labyrinth:
            loot = resolveGeneric(step: step, encounterLevel: encounterLevel, context: context)
        case .contract:
            loot = context.contract(
                for: ContractOffer(id: step.id, difficulty: .easy, enemyID: step.enemyID), encounterLevel: encounterLevel,
            )
        }
        InventoryDuplicatePolicy.appendUniqueItems([loot.item], to: &inventory)
    }

    func matchup(
        state: PlayerProgressionState, enemy: Enemy, enemyLevel: Int,
        profile: EnemyPowerCurve.Profile, seed: UInt64, enemyModifiers: [AffixModifier] = [],
    ) -> ConfiguredSimulationMatchup {
        SimulationMatchupBuilder.build(
            hero: hero, companion: companion, enemy: enemy,
            tier: .band(forLevel: state.heroLevel), heroLevel: state.heroLevel, companionLevel: state.companionLevel,
            enemyLevel: enemyLevel, enemyPowerProfile: profile,
            heroLoadout: heroLoadout, companionLoadout: companionLoadout, seed: seed,
            heroGear: .init(inventory: inventory, loadout: equipment[hero.id] ?? EquipmentLoadout()),
            companionGear: .init(inventory: inventory, loadout: equipment[companion.id] ?? EquipmentLoadout()),
            heroTalents: talents[hero.id] ?? [], companionTalents: talents[companion.id] ?? [],
            enemyAdditionalModifiers: enemyModifiers,
        )
    }

    private func resolveGeneric(step: ModeProgressionStep, encounterLevel: Int, context: BattleLootContext) -> BattleLootResult {
        BattleLoot.resolve(
            LootRequest(seedSalt: step.id, itemID: "\(step.id)-loot", keywordBias: Set(step.keywordBias.map { [$0] } ?? [])),
            encounterLevel: encounterLevel, enemyIsBoss: step.isBoss, worldSeed: worldSeed,
            ownership: context.ownership, partyBias: context.partyBias,
        )
    }
}
