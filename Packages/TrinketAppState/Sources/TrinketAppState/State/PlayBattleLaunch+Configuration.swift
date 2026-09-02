import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

struct BattleLaunchAssembly {
    let configuration: BattleRunConfiguration
    let presentation: BattlePresentationContext
    let universalModifiers: [AffixModifier]
}

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
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil,
    ) -> BattleLaunchAssembly {
        let homesteadEffects = homesteadState.effects
        let members = makePartyMembers(
            input: input,
            homesteadEffects: homesteadEffects,
            rosterState: rosterState,
            inventoryState: inventoryState,
        )
        let heroMember = members.hero
        let companionMember = members.companion
        let resolvedStageReward = input.stageReward ?? .empty
        let enemyLevel = input.enemyEncounterLevel ?? heroMember.progression.level
        let enemyBuild = resolvedEnemyBuild(enemy: input.enemy, level: enemyLevel)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(input.universalModifiers)
        let configuration = BattleRunConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
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
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            heroExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: heroMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestHeroLevel,
                xpPercent: input.experienceBonusPercent,
            ),
            companionExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: companionMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestCompanionLevel,
                xpPercent: input.experienceBonusPercent,
            ),
            materialRewards: StageCompletion.resolvedMaterialRewards(stageReward: resolvedStageReward),
            labyrinthModifiers: input.labyrinthModifiers,
        )
        return BattleLaunchAssembly(
            configuration: configuration,
            presentation: presentation,
            universalModifiers: input.universalModifiers,
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
