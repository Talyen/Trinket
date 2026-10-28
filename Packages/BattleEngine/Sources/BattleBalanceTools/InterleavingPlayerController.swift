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
    let earnedParty: EarnedGearProgression?
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
        equipmentModel: ProgressionEquipmentModel = .earned,
    ) {
        self.hero = hero
        self.companion = companion
        self.worldSeed = worldSeed
        earnedParty = equipmentModel == .earned ? EarnedGearProgression(hero: hero, companion: companion, worldSeed: worldSeed) : nil
        modes = [
            ModeProgress(mode: .campaign, steps: campaignTracker.steps),
            ModeProgress(mode: .spire, steps: spireTracker.steps),
            ModeProgress(mode: .labyrinth, steps: labyrinthTracker.steps),
        ]
        state = initialState
        earnedParty?.invest(state: state)
    }

    var isComplete: Bool {
        modes.allSatisfy { $0.nextStep == nil }
    }

    func selectNextStep() -> ModeProgressionStep? {
        let available = modes.indices.filter { modes[$0].nextStep != nil }
        guard !available.isEmpty else { return nil }

        let unblocked = available.filter { modes[$0].consecutiveLosses < 2 }
        if unblocked.isEmpty {
            return selectRecoveryStep()
        }

        lastEligibleModeIndex = (lastEligibleModeIndex + 1) % unblocked.count
        return modes[unblocked[lastEligibleModeIndex]].nextStep
    }

    /// Also used by explicit checkpoint careers after the finite mode sample ends.
    func selectRecoveryStep() -> ModeProgressionStep {
        if let pendingContract {
            return pendingContract
        }
        var rng = SeededRandomNumberGenerator(seed: worldSeed &+ UInt64(state.totalBattles) &* 97)
        let offer = ContractGenerator.makeOffer(
            difficulty: .easy, eligibleModifiers: [.gold], using: &rng, id: "recovery-\(state.totalBattles)",
        )
        let level = EncounterScaling.contract(.easy).resolve(partyAverageLevel: partyAverageLevel).level
        let step = ModeProgressionStep(
            id: "contract-easy-\(offer.id)-\(offer.enemyID)-\(level)", mode: .contract,
            containerID: "easy", containerTitle: "Contracts", stepIndex: level,
            displayTitle: "Easy Contract L\(level)", enemyID: offer.enemyID, enemyLevel: level, isBoss: false,
        )
        pendingContract = step
        return step
    }

    func recordOutcome(step: ModeProgressionStep, won: Bool, defeatProgress: BattleDefeatProgress? = nil) {
        let modeIndex = modes.firstIndex(where: { $0.mode == step.mode })
        precondition(modeIndex != nil || step.mode == .contract, "Every advancing mode must have progression state")
        state.totalBattles += 1
        if won {
            state.battlesWon += 1
        }
        let enemyLevel = encounterLevel(for: step)
        if won {
            earnedParty?.awardVictory(step: step, encounterLevel: enemyLevel)
        }
        let heroProg = progressionAfterBattle(
            level: state.heroLevel, xp: state.heroXP, enemyLevel: enemyLevel, won: won, defeatProgress: defeatProgress,
        )
        let companionProg = progressionAfterBattle(
            level: state.companionLevel, xp: state.companionXP, enemyLevel: enemyLevel, won: won, defeatProgress: defeatProgress,
        )
        state.heroLevel = heroProg.level
        state.heroXP = heroProg.currentXP
        state.companionLevel = companionProg.level
        state.companionXP = companionProg.currentXP
        earnedParty?.invest(state: state)
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

    private func progressionAfterBattle(
        level: Int, xp: Int, enemyLevel: Int, won: Bool, defeatProgress: BattleDefeatProgress?,
    ) -> CombatantProgression {
        let normalAward = RewardExperiencePolicy.battleExperienceAward(
            playerLevel: level, enemyLevel: enemyLevel, highestLevel: level,
        )
        let award = won ? normalAward : defeatProgress?.experienceAward(from: normalAward) ?? 0
        return CombatantProgression(
            level: level, currentXP: xp, requiredXP: CombatantProgression.requiredXP(forLevel: level),
        ).addingExperience(award)
    }

    func makeMatchup(
        for step: ModeProgressionStep,
        seed: UInt64,
    ) -> ConfiguredSimulationMatchup {
        let enemy = GameContent.enemy(matching: step.enemyID) ?? GameContent.enemies[0]
        if let earnedParty {
            let scaling = step.scaling.resolve(partyAverageLevel: partyAverageLevel)
            return earnedParty.matchup(
                state: state, enemy: enemy, enemyLevel: scaling.level, profile: scaling.profile,
                seed: seed, enemyModifiers: spireModifiers(for: step),
            )
        }
        var rng = SeededRandomNumberGenerator(seed: seed)
        let loadouts = SimulationMatchupBuilder.samplePartyLoadouts(hero: hero, companion: companion, using: &rng)
        let powerTier = SimulationPowerTier.band(forLevel: state.heroLevel)
        // Preserve draw order: both talent kits precede either starter-gear roll.
        let heroTalents = SimulationMatchupBuilder.legalTalentKit(for: hero.id, level: state.heroLevel, using: &rng)
        let companionTalents = SimulationMatchupBuilder.legalTalentKit(for: companion.id, level: state.companionLevel, using: &rng)
        let scaling = step.scaling.resolve(partyAverageLevel: partyAverageLevel)

        return SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: powerTier,
            heroLevel: state.heroLevel,
            companionLevel: state.companionLevel,
            enemyLevel: scaling.level,
            enemyPowerProfile: scaling.profile,
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
        return NodeModifierEffects.combining([modifier]).combatModifiers
    }

    private var partyAverageLevel: Int {
        // Floored party mean in integer arithmetic (exact for level ranges).
        state.heroLevel / 2 + state.companionLevel / 2
            + (state.heroLevel % 2 + state.companionLevel % 2) / 2
    }

    func encounterLevel(for step: ModeProgressionStep) -> Int {
        step.scaling.resolve(partyAverageLevel: partyAverageLevel).level
    }
}
