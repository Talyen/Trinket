import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

struct BattleLaunchAssembly {
    let configuration: BattleRunConfiguration
    let presentation: BattlePresentationContext
    let inputs: BattlePreparationInputs
    var universalModifiers: [AffixModifier] {
        inputs.launch.universalModifiers
    }
}

struct PlayBattlePartySnapshot: Equatable {
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState
    let worldSeed: UInt64

    init(roster: PlayerRosterState, inventory: PlayerInventoryState, homestead: PlayerHomesteadState, worldSeed: UInt64) {
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
        self.worldSeed = worldSeed
    }

    @MainActor
    init(playerSave: PlayerSaveStore) {
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
        worldSeed = playerSave.worldSeed
    }
}

struct BattlePreparationInputs: Equatable {
    let runKey: BattleRunKey?
    let launch: BattleLaunchInput
    let party: PlayBattlePartySnapshot
    let rngSeed: UInt64
    let defeatPrimaryAction: BattleDefeatPrimaryAction
    let hasProgressionRewards: Bool
    let musicStageID: String?
}

struct BattleLaunchInput: Equatable {
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
        worldSeed: UInt64 = 0,
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil,
    ) -> BattleLaunchAssembly {
        assembleLaunch(BattlePreparationInputs(
            runKey: runKey, launch: input,
            party: PlayBattlePartySnapshot(roster: rosterState, inventory: inventoryState, homestead: homesteadState, worldSeed: worldSeed),
            rngSeed: rngSeed, defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards, musicStageID: musicStageID,
        ))
    }

    static func assembleLaunch(_ inputs: BattlePreparationInputs) -> BattleLaunchAssembly {
        let input = inputs.launch
        let rosterState = inputs.party.roster
        let inventoryState = inputs.party.inventory
        let homesteadEffects = inputs.party.homestead.effects
        let members = makePartyMembers(
            input: input,
            homesteadEffects: homesteadEffects,
            rosterState: rosterState,
            inventoryState: inventoryState,
        )
        let heroMember = members.hero
        let companionMember = members.companion
        let enemyLevel = input.enemyEncounterLevel ?? heroMember.progression.level
        let enemyBuild = resolvedEnemyBuild(enemy: input.enemy, level: enemyLevel)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(input.universalModifiers)
        let configuration = BattleRunConfiguration(
            runKey: inputs.runKey,
            rngSeed: inputs.rngSeed,
            hero: heroMember,
            companion: companionMember,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: input.enemyEncounterLevel,
            enemyModifiers: enemyModifiers,
            enemyFaction: GameContent.enemy(matching: input.enemy?.id ?? "")?.faction ?? .mortal,
        )
        let presentation = BattlePresentationContext(
            inventoryItems: inventoryState.items,
            stageReward: input.stageReward,
            rewardItems: resolvedRewardItems(
                stageReward: input.stageReward,
                pendingRewardItem: input.pendingRewardItem,
            ),
            pendingRewardItem: input.pendingRewardItem,
            experienceBonusPercent: input.experienceBonusPercent,
            goldFindPercent: homesteadEffects.goldFindPercent,
            stageRewardsAlreadyClaimed: input.stageRewardsAlreadyClaimed,
            defeatPrimaryAction: inputs.defeatPrimaryAction,
            hasProgressionRewards: inputs.hasProgressionRewards,
            musicStageID: inputs.musicStageID,
            heroExperienceAward: VictoryRewardApplier.battleExperienceAward(
                playerLevel: heroMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestHeroLevel,
                experienceEarnedPercent: input.experienceBonusPercent,
            ),
            companionExperienceAward: VictoryRewardApplier.battleExperienceAward(
                playerLevel: companionMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestCompanionLevel,
                experienceEarnedPercent: input.experienceBonusPercent,
            ),
            materialRewards: StageCompletion.resolvedMaterialRewards(stageReward: input.stageReward ?? .empty),
            labyrinthModifiers: input.labyrinthModifiers,
        )
        return BattleLaunchAssembly(
            configuration: configuration,
            presentation: presentation,
            inputs: inputs,
        )
    }

    private static func makePartyMembers(
        input: BattleLaunchInput,
        homesteadEffects: HomesteadEffects,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
    ) -> (hero: BattleRunConfiguration.PartyMember, companion: BattleRunConfiguration.PartyMember) {
        (
            partyMember(
                combatant: input.hero,
                rosterState: rosterState,
                inventoryState: inventoryState,
                additionalModifiers: homesteadEffects.heroModifiers,
            ),
            partyMember(
                combatant: input.companion,
                rosterState: rosterState,
                inventoryState: inventoryState,
                additionalModifiers: homesteadEffects.companionModifiers,
            ),
        )
    }

    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier] = [],
    ) -> BattleRunConfiguration.PartyMember {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let unlockedTalents = rosterState.unlockedTalents(for: combatant)
        let build = CombatBuildResolver.build(
            combatant: CombatantLevelScaler.scale(
                combatant: combatant,
                level: progression.level,
            ),
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items,
            unlockedTalents: unlockedTalents,
            additionalModifiers: additionalModifiers,
        )
        return BattleRunConfiguration.PartyMember(
            combatant: build.combatant,
            progression: progression,
            equipmentLoadout: equipmentLoadout,
            modifiers: build.modifiers,
            unlockedTalents: unlockedTalents,
        )
    }

    private static func resolvedEnemyBuild(
        enemy: Combatant?,
        level: Int,
    ) -> CombatBuild {
        guard let enemy else {
            return CombatBuild(combatant: Enemy.fallbackCombatant, modifiers: .zero)
        }
        if let catalogEnemy = GameContent.enemy(matching: enemy.id) {
            return CombatBuildResolver.build(enemy: catalogEnemy, level: level)
        }
        var fallbackModifiers = CombatModifierProfile.zero
        fallbackModifiers.outgoingDamagePercent = EnemyPowerCurve.rawDamagePercent(level: level, isBoss: false)
        return CombatBuild(combatant: enemy, modifiers: fallbackModifiers)
    }

    private static func resolvedRewardItems(
        stageReward: StageReward?,
        pendingRewardItem: InventoryItem?,
    ) -> [InventoryItem] {
        if let pendingRewardItem {
            return [pendingRewardItem]
        }
        guard let stageReward else { return [] }
        return stageReward.itemTemplateIDs.compactMap(GameContent.itemTemplate(matching:))
    }
}
