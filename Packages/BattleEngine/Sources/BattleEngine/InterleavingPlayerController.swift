import Foundation
import TrinketContent
import TrinketCore

public struct PlayerProgressionState: Equatable, Sendable {
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
        modeBounces: Int = 0
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

public final class InterleavingPlayerController {
    public let hero: Combatant
    public let companion: Combatant
    public let campaignTracker: CampaignProgressionTracker
    public let spireTracker: SpireProgressionTracker
    public let labyrinthTracker: LabyrinthProgressionTracker

    public private(set) var state: PlayerProgressionState
    public private(set) var campaignIndex = 0
    public private(set) var spireIndex = 0
    public private(set) var labyrinthIndex = 0

    private var consecutiveLosses: [SimulationGameMode: Int] = [:]
    private var lastModeIndex = -1

    public init(
        hero: Combatant = GameContent.heroes[0],
        companion: Combatant = GameContent.companions[0],
        campaignTracker: CampaignProgressionTracker = CampaignProgressionTracker(),
        spireTracker: SpireProgressionTracker = SpireProgressionTracker(),
        labyrinthTracker: LabyrinthProgressionTracker = LabyrinthProgressionTracker(),
        initialState: PlayerProgressionState = PlayerProgressionState()
    ) {
        self.hero = hero
        self.companion = companion
        self.campaignTracker = campaignTracker
        self.spireTracker = spireTracker
        self.labyrinthTracker = labyrinthTracker
        state = initialState
    }

    public var isComplete: Bool {
        campaignIndex >= campaignTracker.steps.count &&
            spireIndex >= spireTracker.steps.count &&
            labyrinthIndex >= labyrinthTracker.steps.count
    }

    public func selectNextStep() -> ModeProgressionStep? {
        guard !isComplete else { return nil }

        let availableModes: [SimulationGameMode] = SimulationGameMode.allCases.filter { mode in
            switch mode {
            case .campaign: campaignIndex < campaignTracker.steps.count
            case .spire: spireIndex < spireTracker.steps.count
            case .labyrinth: labyrinthIndex < labyrinthTracker.steps.count
            }
        }

        guard !availableModes.isEmpty else { return nil }

        let unblockedModes = availableModes.filter { (consecutiveLosses[$0] ?? 0) < 2 }
        let eligibleModes = unblockedModes.isEmpty ? availableModes : unblockedModes

        if unblockedModes.isEmpty {
            for mode in availableModes {
                consecutiveLosses[mode] = 0
            }
        }

        lastModeIndex = (lastModeIndex + 1) % eligibleModes.count
        let selectedMode = eligibleModes[lastModeIndex]

        switch selectedMode {
        case .campaign:
            return campaignTracker.steps[campaignIndex]
        case .spire:
            return spireTracker.steps[spireIndex]
        case .labyrinth:
            return labyrinthTracker.steps[labyrinthIndex]
        }
    }

    public func recordOutcome(step: ModeProgressionStep, won: Bool) {
        state.totalBattles += 1

        if won {
            state.battlesWon += 1
            consecutiveLosses[step.mode] = 0

            let highestLevel = max(state.heroLevel, state.companionLevel)

            let heroAward = ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: state.heroLevel,
                enemyLevel: step.enemyLevel,
                highestLevel: highestLevel
            )
            let companionAward = ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: state.companionLevel,
                enemyLevel: step.enemyLevel,
                highestLevel: highestLevel
            )

            let heroProg = CombatantProgression(
                level: state.heroLevel,
                currentXP: state.heroXP,
                requiredXP: CombatantProgression.requiredXP(forLevel: state.heroLevel)
            ).addingExperience(heroAward)

            let companionProg = CombatantProgression(
                level: state.companionLevel,
                currentXP: state.companionXP,
                requiredXP: CombatantProgression.requiredXP(forLevel: state.companionLevel)
            ).addingExperience(companionAward)

            state.heroLevel = heroProg.level
            state.heroXP = heroProg.currentXP
            state.companionLevel = companionProg.level
            state.companionXP = companionProg.currentXP

            switch step.mode {
            case .campaign: campaignIndex += 1
            case .spire: spireIndex += 1
            case .labyrinth: labyrinthIndex += 1
            }
        } else {
            let losses = (consecutiveLosses[step.mode] ?? 0) + 1
            consecutiveLosses[step.mode] = losses
            if losses == 2 {
                state.modeBounces += 1
            }
        }
    }

    public func makeMatchup(
        for step: ModeProgressionStep,
        seed: UInt64
    ) -> ConfiguredSimulationMatchup {
        var rng = SeededRandomNumberGenerator(seed: seed)

        let enemy = GameContent.enemy(matching: step.enemyID) ?? GameContent.enemies[0]

        let heroProg = CombatantProgression(
            level: state.heroLevel,
            currentXP: state.heroXP,
            requiredXP: CombatantProgression.requiredXP(forLevel: state.heroLevel)
        )
        let companionProg = CombatantProgression(
            level: state.companionLevel,
            currentXP: state.companionXP,
            requiredXP: CombatantProgression.requiredXP(forLevel: state.companionLevel)
        )

        let heroLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: hero,
            level: heroProg.level,
            using: &rng
        )
        let companionLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: companion,
            level: companionProg.level,
            using: &rng
        )

        let powerTier: SimulationPowerTier = if state.heroLevel < 15 {
            .early
        } else if state.heroLevel < 35 {
            .middle
        } else {
            .lateGame
        }

        let keywordBias = step.keywordBias.map { Set([$0]) }

        return SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: powerTier,
            heroLevel: state.heroLevel,
            companionLevel: state.companionLevel,
            enemyLevel: step.enemyLevel,
            heroLoadout: heroLoadout,
            companionLoadout: companionLoadout,
            seed: seed,
            gearKeywordBias: keywordBias
        )
    }
}
