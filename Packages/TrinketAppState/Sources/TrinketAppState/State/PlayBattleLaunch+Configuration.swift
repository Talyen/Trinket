import BattleEngine
import Foundation
import BattleEngine
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Fully resolved battle launch: the engine configuration, the feature presentation
/// context, and the restart-only universal modifiers.
struct BattleLaunchAssembly {
    let configuration: BattleRunConfiguration
    let presentation: BattlePresentationContext
    let universalModifiers: [AffixModifier]
}

/// Save slices that feed battle preparation. Mode owners embed this in their
/// preparation snapshot and re-prepare whenever the snapshot stops matching.
struct PlayBattlePartySnapshot: Equatable {
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState
    let worldSeed: UInt64

    @MainActor
    init(playerSave: PlayerSaveStore) {
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
        worldSeed = playerSave.worldSeed
    }
}

/// Play-orchestrated inputs that feed `PlayBattleLaunch.assembleLaunch`.
///
/// Mode owners and the Play shell resolve the encounter, loot, and policy, then pack
/// them here instead of threading long positional argument lists through the launch
/// helpers.
struct BattleLaunchInput {
    let origin: PlayBattleOrigin?
    let hero: Combatant
    let companion: Combatant
    let enemy: Combatant?
    let enemyEncounterLevel: Int?
    let stageReward: StageReward?
    let experienceBonusPercent: Int
    let pendingRewardItem: InventoryItem?
    let stageRewardsAlreadyClaimed: Bool
    let universalModifiers: [AffixModifier]
    let labyrinthModifiers: [LabyrinthModifierDefinition]
    let heroStartingHealth: Int?
    let companionStartingHealth: Int?

    init(
        origin: PlayBattleOrigin? = nil,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
        labyrinthModifiers: [LabyrinthModifierDefinition] = [],
        heroStartingHealth: Int? = nil,
        companionStartingHealth: Int? = nil
    ) {
        self.origin = origin
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
        self.enemyEncounterLevel = enemyEncounterLevel
        self.stageReward = stageReward
        self.experienceBonusPercent = experienceBonusPercent
        self.pendingRewardItem = pendingRewardItem
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
        self.universalModifiers = universalModifiers
        self.labyrinthModifiers = labyrinthModifiers
        self.heroStartingHealth = heroStartingHealth
        self.companionStartingHealth = companionStartingHealth
    }
}

extension PlayBattleLaunch {
    static func assembleLaunch(
        input: BattleLaunchInput,
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        homesteadState: PlayerHomesteadState = .freshStart,
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil
    ) -> BattleLaunchAssembly {
        let enemyBuild = resolvedEnemyBuild(enemy: input.enemy)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(input.universalModifiers)
        let homesteadEffects = homesteadState.effects
        let members = makePartyMembers(
            input: input,
            homesteadEffects: homesteadEffects,
            rosterState: rosterState,
            inventoryState: inventoryState
        )
        let heroMember = members.hero
        let companionMember = members.companion
        let resolvedStageReward = input.stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let enemyLevel = input.enemyEncounterLevel ?? heroMember.progression.level
        let configuration = BattleRunConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: heroMember,
            companion: companionMember,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: input.enemyEncounterLevel,
            enemyModifiers: enemyModifiers,
            enemyFaction: GameContent.enemy(matching: input.enemy?.id ?? "")?.faction ?? .mortal
        )
        let presentation = BattlePresentationContext(
            inventoryItems: inventoryState.items,
            stageReward: input.stageReward,
            rewardItems: resolvedRewardItems(
                stageReward: input.stageReward,
                pendingRewardItem: input.pendingRewardItem
            ),
            pendingRewardItem: input.pendingRewardItem,
            experienceBonusPercent: input.experienceBonusPercent,
            goldFindPercent: homesteadEffects.goldFindPercent,
            stageRewardsAlreadyClaimed: input.stageRewardsAlreadyClaimed,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            heroExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: heroMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestHeroLevel,
                xpPercent: input.experienceBonusPercent
            ),
            companionExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: companionMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestCompanionLevel,
                xpPercent: input.experienceBonusPercent
            ),
            materialRewards: StageCompletion.resolvedMaterialRewards(stageReward: resolvedStageReward),
            labyrinthModifiers: input.labyrinthModifiers
        )
        return BattleLaunchAssembly(
            configuration: configuration,
            presentation: presentation,
            universalModifiers: input.universalModifiers
        )
    }

    private static func makePartyMembers(
        input: BattleLaunchInput,
        homesteadEffects: HomesteadEffects,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState
    ) -> (hero: BattleRunConfiguration.PartyMember, companion: BattleRunConfiguration.PartyMember) {
        (
            partyMember(
                combatant: input.hero,
                startingHealth: input.heroStartingHealth,
                rosterState: rosterState,
                inventoryState: inventoryState,
                additionalModifiers: homesteadEffects.heroModifiers
            ),
            partyMember(
                combatant: input.companion,
                startingHealth: input.companionStartingHealth,
                rosterState: rosterState,
                inventoryState: inventoryState,
                additionalModifiers: homesteadEffects.companionModifiers
            )
        )
    }

    private static func partyMember(
        combatant: Combatant,
        startingHealth: Int?,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier] = []
    ) -> BattleRunConfiguration.PartyMember {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let unlockedTalents = rosterState.unlockedTalents(for: combatant)
        let build = CombatBuildResolver.build(
            combatant: CombatantLevelScaler.scale(
                combatant: combatant,
                level: progression.level
            ),
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items,
            unlockedTalents: unlockedTalents,
            additionalModifiers: additionalModifiers
        )
        return BattleRunConfiguration.PartyMember(
            combatant: build.combatant,
            progression: progression,
            equipmentLoadout: equipmentLoadout,
            modifiers: build.modifiers,
            unlockedTalents: unlockedTalents,
            startingHealth: startingHealth.map {
                min(max(1, $0), build.effectiveMaxHealth)
            }
        )
    }

    /// Bakes the active party exactly as a battle launch would, for
    /// out-of-battle health consumers like the Campfire screen.
    static func bakedActiveParty(
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        homesteadState: PlayerHomesteadState
    ) -> (hero: BattleRunConfiguration.PartyMember, companion: BattleRunConfiguration.PartyMember) {
        let input = BattleLaunchInput(
            hero: rosterState.activeHero,
            companion: rosterState.activeCompanion
        )
        return makePartyMembers(
            input: input,
            homesteadEffects: homesteadState.effects,
            rosterState: rosterState,
            inventoryState: inventoryState
        )
    }

    private static func resolvedEnemyBuild(
        enemy: Combatant?
    ) -> CombatBuild {
        guard let enemy else {
            return CombatBuild(combatant: Enemy.fallbackCombatant, modifiers: .zero)
        }
        // Preserve the encounter combatant (already scaled by launch).
        // Only resolve trait modifiers from the catalog entry — do not replace scaled stats
        // with the catalog base combatant.
        if let catalogEnemy = GameContent.enemy(matching: enemy.id) {
            let catalogBuild = CombatBuildResolver.build(enemy: catalogEnemy)
            return CombatBuild(combatant: enemy, modifiers: catalogBuild.modifiers)
        }
        return CombatBuild(combatant: enemy, modifiers: .zero)
    }

    private static func resolvedRewardItems(
        stageReward: StageReward?,
        pendingRewardItem: InventoryItem?
    ) -> [InventoryItem] {
        if let pendingRewardItem {
            return [pendingRewardItem]
        }
        guard let stageReward else { return [] }
        return stageReward.itemTemplateIDs.compactMap(GameContent.itemTemplate(matching:))
    }
}
