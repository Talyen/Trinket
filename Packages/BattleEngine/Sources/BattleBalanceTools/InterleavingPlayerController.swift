import TrinketContent
import TrinketCore

public struct PlayerProgressionState: Equatable, Codable, Sendable {
    public var heroLevel: Int
    public var heroXP: Int
    public var companionLevel: Int
    public var companionXP: Int
    public var totalBattles: Int
    public var battlesWon: Int
    public var modeBounces: Int

    public init(
        heroLevel: Int = 1,
        heroXP: Int = 0,
        companionLevel: Int = 1,
        companionXP: Int = 0,
        totalBattles: Int = 0,
        battlesWon: Int = 0,
        modeBounces: Int = 0,
    ) {
        self.heroLevel = max(1, heroLevel)
        self.heroXP = max(0, heroXP)
        self.companionLevel = max(1, companionLevel)
        self.companionXP = max(0, companionXP)
        self.totalBattles = totalBattles
        self.battlesWon = battlesWon
        self.modeBounces = modeBounces
    }

    public var averageLevel: Double {
        (Double(heroLevel) + Double(companionLevel)) / 2.0
    }
}

final class InterleavingPlayerController {
    private let hero: Combatant
    private let companion: Combatant
    private let worldSeed: UInt64
    private var pendingContract: ModeProgressionStep?
    private(set) var state: PlayerProgressionState

    private struct ModeProgress {
        let mode: SimulationGameMode
        let steps: [ModeProgressionStep]
        var nextIndex = 0
        var consecutiveLosses = 0

        var nextStep: ModeProgressionStep? {
            steps.indices.contains(nextIndex) ? steps[nextIndex] : nil
        }
    }

    private var modes: [ModeProgress]
    private var lastEligibleModeIndex = -1

    init(
        hero: Combatant = GameContent.heroes[0],
        companion: Combatant = GameContent.companions[0],
        campaignTracker: ModeProgressionTracker = ModeProgressionTracker.campaign(),
        spireTracker: ModeProgressionTracker = ModeProgressionTracker.spire(),
        labyrinthTracker: ModeProgressionTracker = ModeProgressionTracker.labyrinth(),
        initialState: PlayerProgressionState = PlayerProgressionState(),
        worldSeed: UInt64 = 1,
    ) {
        self.hero = hero
        self.companion = companion
        self.worldSeed = worldSeed
        modes = [SimulationGameMode.campaign, .spire, .labyrinth].map { mode in
            let tracker = switch mode {
            case .campaign: campaignTracker
            case .spire: spireTracker
            case .labyrinth: labyrinthTracker
            case .contract: preconditionFailure("Contracts are recovery jobs, not advancing content")
            }
            let steps = tracker.steps.filter { step in
                guard step.mode == .spire else { return true }
                guard let spire = GameContent.spire(id: SpireID(step.containerID)) else { return false }
                return SpireAttunement.evaluate(hero: hero, companion: companion, spire: spire).isReady
            }
            return ModeProgress(mode: mode, steps: steps)
        }
        state = initialState
    }

    var isComplete: Bool {
        modes.allSatisfy { $0.nextStep == nil }
    }

    func selectNextStep() -> ModeProgressionStep? {
        let available = modes.indices.filter { modes[$0].nextStep != nil }
        guard !available.isEmpty else { return nil }

        let unblocked = available.filter { modes[$0].consecutiveLosses < 2 }
        if unblocked.isEmpty {
            if let pendingContract {
                return pendingContract
            }
            var rng = SeededRandomNumberGenerator(seed: worldSeed &+ UInt64(state.totalBattles) &* 97)
            let offer = ContractGenerator.makeOffer(
                difficulty: .easy, eligibleModifiers: [.gold], using: &rng, id: "recovery-\(state.totalBattles)",
            )
            let level = EncounterLevelResolver.contractEnemyLevel(difficulty: .easy, partyAverageLevel: partyAverageLevel)
            let step = ModeProgressionStep(
                id: "contract-easy-\(offer.enemyID)-\(level)", mode: .contract,
                containerID: "easy", containerTitle: "Contracts", stepIndex: level,
                displayTitle: "Easy Contract L\(level)", enemyID: offer.enemyID,
                enemyLevel: level, isBoss: false,
            )
            pendingContract = step
            return step
        }

        lastEligibleModeIndex = (lastEligibleModeIndex + 1) % unblocked.count
        return modes[unblocked[lastEligibleModeIndex]].nextStep
    }

    func recordOutcome(step: ModeProgressionStep, won: Bool, defeatProgress: BattleDefeatProgress? = nil) {
        let modeIndex = modes.firstIndex(where: { $0.mode == step.mode })
        precondition(modeIndex != nil || step.mode == .contract, "Every advancing mode must have progression state")
        state.totalBattles += 1
        if won {
            state.battlesWon += 1
        }
        let enemyLevel = encounterLevel(for: step)
        let heroNormal = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: state.heroLevel,
            enemyLevel: enemyLevel,
            highestLevel: state.heroLevel,
        )
        let companionNormal = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: state.companionLevel,
            enemyLevel: enemyLevel,
            highestLevel: state.companionLevel,
        )
        let heroAward = won ? heroNormal : defeatProgress?.experienceAward(from: heroNormal) ?? 0
        let companionAward = won ? companionNormal : defeatProgress?.experienceAward(from: companionNormal) ?? 0
        let heroProg = CombatantProgression(
            level: state.heroLevel,
            currentXP: state.heroXP,
            requiredXP: CombatantProgression.requiredXP(forLevel: state.heroLevel),
        )
        .addingExperience(heroAward)
        let companionProg = CombatantProgression(
            level: state.companionLevel,
            currentXP: state.companionXP,
            requiredXP: CombatantProgression.requiredXP(forLevel: state.companionLevel),
        )
        .addingExperience(companionAward)
        state.heroLevel = heroProg.level
        state.heroXP = heroProg.currentXP
        state.companionLevel = companionProg.level
        state.companionXP = companionProg.currentXP
        if won {
            if let modeIndex {
                modes[modeIndex].consecutiveLosses = 0
                modes[modeIndex].nextIndex += 1
            } else {
                for index in modes.indices {
                    modes[index].consecutiveLosses = 0
                }
            }
        } else if let modeIndex {
            modes[modeIndex].consecutiveLosses += 1
            if modes[modeIndex].consecutiveLosses == 2 {
                state.modeBounces += 1
            }
        }
        if step.mode == .contract, won {
            pendingContract = nil
        }
    }

    func makeMatchup(
        for step: ModeProgressionStep,
        seed: UInt64,
    ) -> ConfiguredSimulationMatchup {
        var rng = SeededRandomNumberGenerator(seed: seed)
        let enemy = GameContent.enemy(matching: step.enemyID) ?? GameContent.enemies[0]
        let loadouts = SimulationMatchupBuilder.samplePartyLoadouts(hero: hero, companion: companion, using: &rng)
        let powerTier = SimulationPowerTier.band(forLevel: state.heroLevel)
        // Preserve draw order: both talent kits precede either starter-gear roll.
        let heroTalents = SimulationMatchupBuilder.legalTalentKit(for: hero.id, level: state.heroLevel, using: &rng)
        let companionTalents = SimulationMatchupBuilder.legalTalentKit(for: companion.id, level: state.companionLevel, using: &rng)

        return SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: powerTier,
            heroLevel: state.heroLevel,
            companionLevel: state.companionLevel,
            enemyLevel: encounterLevel(for: step),
            enemyPowerProfile: step.mode.enemyPowerProfile,
            heroLoadout: loadouts.hero,
            companionLoadout: loadouts.companion,
            seed: seed,
            heroGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: hero,
                loadout: loadouts.hero,
                tier: powerTier,
                level: state.heroLevel,
                idPrefix: "prog-hero",
                using: &rng,
            ),
            companionGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: companion,
                loadout: loadouts.companion,
                tier: powerTier,
                level: state.companionLevel,
                idPrefix: "prog-companion",
                using: &rng,
            ),
            heroTalents: heroTalents,
            companionTalents: companionTalents,
            enemyAdditionalModifiers: spireModifiers(for: step),
        )
    }

    private func spireModifiers(for step: ModeProgressionStep) -> [AffixModifier] {
        guard step.mode == .spire,
              let floor = GameContent.spireFloor(spireID: SpireID(step.containerID), floor: step.stepIndex),
              let modifier = GameContent.spireModifier(for: floor, worldSeed: worldSeed)
        else { return [] }
        switch modifier.effect {
        case let .damageDealt(keyword, amount): return [.damageDealt(keyword, amount)]
        case let .damageTakenReduction(keyword, percent): return [.damageTakenPercent(keyword, Double(percent) / 100)]
        default: return [] // Spire keyword rewards do not modify combat.
        }
    }

    private var partyAverageLevel: Int {
        // Floored party mean in integer arithmetic (exact for level ranges).
        state.heroLevel / 2 + state.companionLevel / 2
            + (state.heroLevel % 2 + state.companionLevel % 2) / 2
    }

    func encounterLevel(for step: ModeProgressionStep) -> Int {
        switch step.mode {
        case .campaign:
            EncounterLevelResolver.campaignAdjusted(step.enemyLevel, partyAverageLevel: partyAverageLevel)
        case .spire:
            step.enemyLevel
        case .labyrinth:
            EncounterLevelResolver.labyrinthAdjusted(step.enemyLevel, partyAverageLevel: partyAverageLevel)
        case .contract:
            EncounterLevelResolver.contractEnemyLevel(difficulty: .easy, partyAverageLevel: partyAverageLevel)
        }
    }
}
