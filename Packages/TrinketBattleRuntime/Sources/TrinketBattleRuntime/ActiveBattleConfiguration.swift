import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

/// Battle-run DTO of pre-resolved party, enemy, and reward inputs.
///
/// Play owns building this snapshot. The battle presentation feature consumes it
/// without reading live save slices or re-deriving persistence policy.
public struct ActiveBattleConfiguration: Identifiable {
    public struct PartyMember: Equatable {
        public let combatant: Combatant
        public let progression: CombatantProgression
        public let equipmentLoadout: EquipmentLoadout
        public let modifiers: CombatModifierProfile

        public init(
            combatant: Combatant,
            progression: CombatantProgression,
            equipmentLoadout: EquipmentLoadout,
            modifiers: CombatModifierProfile
        ) {
            self.combatant = combatant
            self.progression = progression
            self.equipmentLoadout = equipmentLoadout
            self.modifiers = modifiers
        }
    }

    public let id = UUID()
    /// Opaque prepared-run key. Battle stores and matches keys but never interprets them.
    public let runKey: BattleRunKey?
    public let rngSeed: UInt64
    public let hero: PartyMember
    public let companion: PartyMember
    public let enemy: Combatant?
    public let enemyEncounterLevel: Int?
    public let highestHeroLevel: Int
    public let highestCompanionLevel: Int
    public let enemyModifiers: CombatModifierProfile
    /// Value snapshot used by detail presentation; live inventory remains app-owned.
    public let inventoryItems: [InventoryItem]
    public let stageReward: StageReward?
    public let rewardItems: [InventoryItem]
    public let pendingRewardItem: InventoryItem?
    public let experienceBonusPercent: Int
    /// Homestead gold-find baked at launch for deterministic victory display.
    public let goldFindPercent: Int
    /// Journey claimed-stage policy baked at launch.
    public let stageRewardsAlreadyClaimed: Bool
    public let universalModifiers: [AffixModifier]
    /// Defeat chrome action baked at launch so UI never branches on mode.
    public let defeatPrimaryAction: BattleDefeatPrimaryAction
    /// Whether victory grants progression rewards.
    public let hasProgressionRewards: Bool
    /// Journey stage id used only by app-level music routing.
    public let musicStageID: String?
    public let heroExperienceAward: Int
    public let companionExperienceAward: Int
    public let materialRewards: [ResourceAmount]

    public init(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64,
        hero: PartyMember,
        companion: PartyMember,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        highestHeroLevel: Int,
        highestCompanionLevel: Int,
        enemyModifiers: CombatModifierProfile,
        inventoryItems: [InventoryItem] = [],
        stageReward: StageReward? = nil,
        rewardItems: [InventoryItem] = [],
        pendingRewardItem: InventoryItem? = nil,
        experienceBonusPercent: Int = 0,
        goldFindPercent: Int = 0,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil,
        heroExperienceAward: Int = 0,
        companionExperienceAward: Int = 0,
        materialRewards: [ResourceAmount] = []
    ) {
        self.runKey = runKey
        self.rngSeed = rngSeed
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
        self.enemyEncounterLevel = enemyEncounterLevel
        self.highestHeroLevel = highestHeroLevel
        self.highestCompanionLevel = highestCompanionLevel
        self.enemyModifiers = enemyModifiers
        self.inventoryItems = inventoryItems
        self.stageReward = stageReward
        self.rewardItems = rewardItems
        self.pendingRewardItem = pendingRewardItem
        self.experienceBonusPercent = experienceBonusPercent
        self.goldFindPercent = goldFindPercent
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
        self.universalModifiers = universalModifiers
        self.defeatPrimaryAction = defeatPrimaryAction
        self.hasProgressionRewards = hasProgressionRewards
        self.musicStageID = musicStageID
        self.heroExperienceAward = heroExperienceAward
        self.companionExperienceAward = companionExperienceAward
        self.materialRewards = materialRewards
    }

    public func partyMember(for combatantID: String) -> PartyMember? {
        if combatantID == hero.combatant.id {
            return hero
        }
        if combatantID == companion.combatant.id {
            return companion
        }
        return nil
    }
}
