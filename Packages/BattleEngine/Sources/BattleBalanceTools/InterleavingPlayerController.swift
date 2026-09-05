import Foundation
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
        initialState: PlayerProgressionState = PlayerProgressionState(),
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
            let heroPartyAvg = Int(state.averageLevel.rounded())
            let resolvedEnemyLevel = step.mode == .spire
                ? EncounterLevelResolver.partyAdjusted(step.enemyLevel, partyAverageLevel: heroPartyAvg)
                : step.enemyLevel

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
        seed: UInt64,
    ) -> ConfiguredSimulationMatchup {
        var rng = SeededRandomNumberGenerator(seed: seed)

        let enemy = GameContent.enemy(matching: step.enemyID) ?? GameContent.enemies[0]

        let party = preparePartyMatchup(step: step, using: &rng)

        return SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: party.powerTier,
            heroLevel: party.heroLevel,
            companionLevel: party.companionLevel,
            enemyLevel: party.enemyLevel,
            heroLoadout: party.heroLoadout,
            companionLoadout: party.companionLoadout,
            seed: seed,
            heroGear: party.heroGear,
            companionGear: party.companionGear,
            heroTalents: party.heroTalents,
            companionTalents: party.companionTalents,
            gearKeywordBias: party.keywordBias,
        )
    }

    private struct PartyMatchupSetup {
        var heroLevel: Int
        var companionLevel: Int
        var enemyLevel: Int
        var powerTier: SimulationPowerTier
        var heroLoadout: AbilityLoadout
        var companionLoadout: AbilityLoadout
        var heroTalents: Set<String>
        var companionTalents: Set<String>
        var heroGear: SimulationMatchupBuilder.GearOverride?
        var companionGear: SimulationMatchupBuilder.GearOverride?
        var keywordBias: Set<Keyword>?
    }

    private func preparePartyMatchup(
        step: ModeProgressionStep,
        using rng: inout some RandomNumberGenerator,
    ) -> PartyMatchupSetup {
        let partyLoadouts = SimulationMatchupBuilder.samplePartyLoadouts(
            hero: hero,
            companion: companion,
            using: &rng,
        )
        let heroLevel = simulatedHeroLevel(for: step)
        let companionLevel = simulatedCompanionLevel(for: step)
        let powerTier = SimulationPowerTier.band(forLevel: heroLevel)
        let partyAvg = Int(((Double(heroLevel) + Double(companionLevel)) / 2.0).rounded())
        let enemyLevel = step.mode == .spire
            ? EncounterLevelResolver.partyAdjusted(step.enemyLevel, partyAverageLevel: partyAvg)
            : step.enemyLevel
        let keywordBias = step.keywordBias.map { Set([$0]) }

        return PartyMatchupSetup(
            heroLevel: heroLevel,
            companionLevel: companionLevel,
            enemyLevel: enemyLevel,
            powerTier: powerTier,
            heroLoadout: partyLoadouts.hero,
            companionLoadout: partyLoadouts.companion,
            heroTalents: SimulationMatchupBuilder.legalTalentKit(for: hero.id, level: heroLevel, using: &rng),
            companionTalents: SimulationMatchupBuilder.legalTalentKit(for: companion.id, level: companionLevel, using: &rng),
            heroGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: hero,
                loadout: partyLoadouts.hero,
                tier: powerTier,
                level: heroLevel,
                idPrefix: "prog-hero",
                gearKeywordBias: keywordBias,
                using: &rng,
            ),
            companionGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: companion,
                loadout: partyLoadouts.companion,
                tier: powerTier,
                level: companionLevel,
                idPrefix: "prog-companion",
                gearKeywordBias: keywordBias,
                using: &rng,
            ),
            keywordBias: keywordBias,
        )
    }

    public func simulatedHeroLevel(for _: ModeProgressionStep) -> Int {
        state.heroLevel
    }

    public func simulatedCompanionLevel(for _: ModeProgressionStep) -> Int {
        state.companionLevel
    }
}
