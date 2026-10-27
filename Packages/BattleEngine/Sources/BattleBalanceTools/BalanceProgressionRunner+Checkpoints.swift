import BattleEngine
import TrinketContent
import TrinketCore

/// Frozen earned inventory and party selections at first reaching a target level.
/// Probe fights never award XP or loot back into this snapshot.
public struct EarnedCareerCheckpoint: Sendable {
    public let targetLevel: Int
    public let state: PlayerProgressionState
    public let hero: Combatant
    public let companion: Combatant
    public let inventory: [InventoryItem]
    public let equipment: [String: EquipmentLoadout]
    public let talents: [String: Set<String>]
    public let heroLoadout: AbilityLoadout
    public let companionLoadout: AbilityLoadout

    init(targetLevel: Int, state: PlayerProgressionState, party: EarnedGearProgression) {
        self.targetLevel = targetLevel
        self.state = state
        hero = party.hero
        companion = party.companion
        inventory = party.inventory
        equipment = party.equipment
        talents = party.talents
        heroLoadout = party.heroLoadout
        companionLoadout = party.companionLoadout
    }

    public func matchup(enemy: Enemy, seed: UInt64) -> ConfiguredSimulationMatchup {
        SimulationMatchupBuilder.build(
            hero: hero, companion: companion, enemy: enemy, tier: .band(forLevel: state.heroLevel),
            heroLevel: state.heroLevel, companionLevel: state.companionLevel, enemyLevel: targetLevel,
            heroLoadout: heroLoadout, companionLoadout: companionLoadout, seed: seed,
            heroGear: .init(inventory: inventory, loadout: equipment[hero.id] ?? EquipmentLoadout()),
            companionGear: .init(inventory: inventory, loadout: equipment[companion.id] ?? EquipmentLoadout()),
            heroTalents: talents[hero.id] ?? [], companionTalents: talents[companion.id] ?? [],
        )
    }
}

public struct EarnedCareerCheckpointRun: Sendable {
    public let seed: UInt64
    public let checkpoints: [EarnedCareerCheckpoint]
    public let trainingRecords: [ProgressionBattleRecord]
    public let endState: PlayerProgressionState
    public let didTruncate: Bool
}

public extension BalanceProgressionRunner {
    /// Finite mode sample first, renewable Easy Contracts afterwards. This is a
    /// disclosed training route, not a representative estimate of player time.
    /// All targets share one uninterrupted fresh, ungeared career per run.
    static func earnedCheckpoints(
        config: BalanceSweepConfig, policy: PlayPolicy, levels: [Int],
    ) -> [EarnedCareerCheckpointRun] {
        let targets = Array(Set(levels.filter { $0 >= 1 })).sorted()
        guard let lastTarget = targets.last else { return [] }
        let roster = config.resolvedRoster
        precondition(!roster.heroes.isEmpty && !roster.companions.isEmpty)
        let work = config.workIndices(count: max(1, config.battlesPerTier))
        return SweepWorkerPool.map(count: work.count, jobs: config.resolvedJobs) { offset in
            let index = work.lowerBound + offset
            let seed = config.seed &+ UInt64(index) &* 1000003
            let hero = roster.heroes[index % roster.heroes.count]
            let companionIndex = BalanceSweepRunner.identityCompanionIndex(
                sampleIndex: index, heroCount: roster.heroes.count, companionCount: roster.companions.count,
            )
            let controller = InterleavingPlayerController(
                hero: hero, companion: roster.companions[companionIndex],
                campaignTracker: .campaign(worldSeed: seed), worldSeed: seed,
            )
            var snapshots: [EarnedCareerCheckpoint] = []
            var records: [ProgressionBattleRecord] = []
            var nextTarget = 0
            while true {
                while targets.indices.contains(nextTarget), controller.state.averageLevel >= Double(targets[nextTarget]) {
                    if let party = controller.earnedParty {
                        snapshots.append(EarnedCareerCheckpoint(targetLevel: targets[nextTarget], state: controller.state, party: party))
                    }
                    nextTarget += 1
                }
                if controller.state.averageLevel >= Double(lastTarget) || records.count >= maxBattlesPerRun {
                    break
                }
                let step = controller.selectNextStep() ?? controller.selectRecoveryStep()
                let battleSeed = seed &+ UInt64(records.count + 1) &* 97
                records.append(simulateBattle(
                    controller: controller, step: step, seed: battleSeed, config: config, policy: policy,
                ))
            }
            return EarnedCareerCheckpointRun(
                seed: seed, checkpoints: snapshots, trainingRecords: records, endState: controller.state,
                didTruncate: snapshots.count != targets.count,
            )
        }
    }
}
