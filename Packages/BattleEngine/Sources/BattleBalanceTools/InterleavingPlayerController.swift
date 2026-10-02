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
    ) {
        self.hero = hero
        self.companion = companion
        modes = SimulationGameMode.allCases.map { mode in
            let tracker = switch mode {
            case .campaign: campaignTracker
            case .spire: spireTracker
            case .labyrinth: labyrinthTracker
            }
            return ModeProgress(mode: mode, steps: tracker.steps)
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
        let eligible = unblocked.isEmpty ? available : unblocked
        if unblocked.isEmpty {
            for index in available {
                modes[index].consecutiveLosses = 0
            }
        }

        lastEligibleModeIndex = (lastEligibleModeIndex + 1) % eligible.count
        return modes[eligible[lastEligibleModeIndex]].nextStep
    }

    func recordOutcome(step: ModeProgressionStep, won: Bool) {
        guard let modeIndex = modes.firstIndex(where: { $0.mode == step.mode }) else {
            preconditionFailure("Every simulation mode must have progression state")
        }
        state.totalBattles += 1

        if won {
            state.battlesWon += 1
            modes[modeIndex].consecutiveLosses = 0

            let highestLevel = max(state.heroLevel, state.companionLevel)
            let resolvedEnemyLevel = encounterLevel(for: step)

            let heroAward = ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: state.heroLevel,
                enemyLevel: resolvedEnemyLevel,
                highestLevel: highestLevel,
            )
            let companionAward = ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: state.companionLevel,
                enemyLevel: resolvedEnemyLevel,
                highestLevel: highestLevel,
            )

            let heroProg = CombatantProgression(
                level: state.heroLevel,
                currentXP: state.heroXP,
                requiredXP: CombatantProgression.requiredXP(forLevel: state.heroLevel),
            ).addingExperience(heroAward)

            let companionProg = CombatantProgression(
                level: state.companionLevel,
                currentXP: state.companionXP,
                requiredXP: CombatantProgression.requiredXP(forLevel: state.companionLevel),
            ).addingExperience(companionAward)

            state.heroLevel = heroProg.level
            state.heroXP = heroProg.currentXP
            state.companionLevel = companionProg.level
            state.companionXP = companionProg.currentXP

            modes[modeIndex].nextIndex += 1
        } else {
            modes[modeIndex].consecutiveLosses += 1
            if modes[modeIndex].consecutiveLosses == 2 {
                state.modeBounces += 1
            }
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
        let keywordBias = step.keywordBias.map { Set([$0]) }
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
            heroLoadout: loadouts.hero,
            companionLoadout: loadouts.companion,
            seed: seed,
            heroGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: hero,
                loadout: loadouts.hero,
                tier: powerTier,
                level: state.heroLevel,
                idPrefix: "prog-hero",
                gearKeywordBias: keywordBias,
                using: &rng,
            ),
            companionGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: companion,
                loadout: loadouts.companion,
                tier: powerTier,
                level: state.companionLevel,
                idPrefix: "prog-companion",
                gearKeywordBias: keywordBias,
                using: &rng,
            ),
            heroTalents: heroTalents,
            companionTalents: companionTalents,
            gearKeywordBias: keywordBias,
        )
    }

    func encounterLevel(for step: ModeProgressionStep) -> Int {
        // Floored party mean in integer arithmetic (exact for level ranges).
        let partyAverage = state.heroLevel / 2 + state.companionLevel / 2
            + (state.heroLevel % 2 + state.companionLevel % 2) / 2
        switch step.mode {
        case .campaign:
            return EncounterLevelResolver.campaignAdjusted(step.enemyLevel, partyAverageLevel: partyAverage)
        case .spire:
            return step.enemyLevel
        case .labyrinth:
            return EncounterLevelResolver.labyrinthAdjusted(step.enemyLevel, partyAverageLevel: partyAverage)
        }
    }
}
