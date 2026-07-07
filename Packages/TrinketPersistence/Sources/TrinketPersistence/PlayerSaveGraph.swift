// swiftlint:disable file_length
import Foundation
import SwiftData
import TrinketContent
import TrinketCore

@Model
public final class PlayerSaveRoot {
    public var id: String = "primary"
    public var schemaVersion: Int = PlayerSave.currentSchemaVersion
    public var modifiedAt: Date = Date()
    public var sessionGeneration: UInt64 = 0

    @Relationship(deleteRule: .cascade, inverse: \JourneyProgressModel.root)
    public var journey: JourneyProgressModel?
    @Relationship(deleteRule: .cascade, inverse: \RosterModel.root)
    public var roster: RosterModel?
    @Relationship(deleteRule: .cascade, inverse: \InventoryModel.root)
    public var inventory: InventoryModel?
    @Relationship(deleteRule: .cascade, inverse: \HomesteadModel.root)
    public var homestead: HomesteadModel?

    public init(id: String = "primary") {
        self.id = id
    }
}

@Model
public final class JourneyProgressModel {
    public var activeChapterID: String = JourneyProgressState.initial.activeChapterID
    public var activeStageID: String?
    public var lastCompletedStageID: String?
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \JourneyStageProgressModel.journey)
    public var stages: [JourneyStageProgressModel]?

    public init() {}
}

@Model
public final class JourneyStageProgressModel {
    public var stageID: String = ""
    public var isCompleted: Bool = false
    public var rewardsClaimed: Bool = false
    public var journey: JourneyProgressModel?

    public init(stageID: String = "", isCompleted: Bool = false, rewardsClaimed: Bool = false) {
        self.stageID = stageID
        self.isCompleted = isCompleted
        self.rewardsClaimed = rewardsClaimed
    }
}

@Model
public final class RosterModel {
    public var activeHeroID: String = PlayerRosterState.starterHeroID
    public var activePetID: String = PlayerRosterState.starterPetID
    public var gold: Int = 0
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \UnlockedCombatantModel.roster)
    public var unlockedCombatants: [UnlockedCombatantModel]?
    @Relationship(deleteRule: .cascade, inverse: \CombatantProgressionModel.roster)
    public var progressions: [CombatantProgressionModel]?
    @Relationship(deleteRule: .cascade, inverse: \AbilityLoadoutModel.roster)
    public var abilityLoadouts: [AbilityLoadoutModel]?
    @Relationship(deleteRule: .cascade, inverse: \EquipmentLoadoutModel.roster)
    public var equipmentLoadouts: [EquipmentLoadoutModel]?
    @Relationship(deleteRule: .cascade, inverse: \PrimaryStatsModel.roster)
    public var primaryStats: [PrimaryStatsModel]?

    public init() {}
}

@Model
public final class UnlockedCombatantModel {
    public var combatantID: String = ""
    public var role: String = ""
    public var roster: RosterModel?

    public init(combatantID: String = "", role: String = "") {
        self.combatantID = combatantID
        self.role = role
    }
}

@Model
public final class CombatantProgressionModel {
    public var combatantID: String = ""
    public var level: Int = 1
    public var currentXP: Int = 0
    public var requiredXP: Int = CombatantProgression.requiredXP(forLevel: 1)
    public var roster: RosterModel?

    public init(combatantID: String = "", progression: CombatantProgression = .initial) {
        self.combatantID = combatantID
        level = progression.level
        currentXP = progression.currentXP
        requiredXP = progression.requiredXP
    }
}

@Model
public final class AbilityLoadoutModel {
    public var combatantID: String = ""
    public var basicID: String?
    public var skillID: String?
    public var ultimateID: String?
    public var roster: RosterModel?

    public init(combatantID: String = "", loadout: AbilityLoadout = AbilityLoadout()) {
        self.combatantID = combatantID
        basicID = loadout.basic?.id
        skillID = loadout.skill?.id
        ultimateID = loadout.ultimate?.id
    }
}

@Model
public final class EquipmentLoadoutModel {
    public var combatantID: String = ""
    public var roster: RosterModel?

    @Relationship(deleteRule: .cascade, inverse: \EquipmentSlotModel.loadout)
    public var slots: [EquipmentSlotModel]?

    public init(combatantID: String = "") {
        self.combatantID = combatantID
    }
}

@Model
public final class EquipmentSlotModel {
    public var slotID: String = ""
    public var itemID: String = ""
    public var loadout: EquipmentLoadoutModel?

    public init(slotID: String = "", itemID: String = "") {
        self.slotID = slotID
        self.itemID = itemID
    }
}

@Model
public final class PrimaryStatsModel {
    public var combatantID: String = ""
    public var strength: Int = 0
    public var agility: Int = 0
    public var toughness: Int = 0
    public var intellect: Int = 0
    public var wisdom: Int = 0
    public var roster: RosterModel?

    public init(combatantID: String = "", stats: PrimaryStats = PrimaryStats()) {
        self.combatantID = combatantID
        strength = stats.strength
        agility = stats.agility
        toughness = stats.toughness
        intellect = stats.intellect
        wisdom = stats.wisdom
    }
}

@Model
public final class InventoryModel {
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \InventoryItemModel.inventory)
    public var items: [InventoryItemModel]?

    public init() {}
}

@Model
public final class InventoryItemModel {
    public var id: String = ""
    public var templateID: String = ""
    public var baseTypeID: String = ""
    public var rarityID: String = Rarity.basic.rawValue
    public var displayName: String = ""
    public var sortIndex: Int = 0
    public var inventory: InventoryModel?

    @Relationship(deleteRule: .cascade, inverse: \ItemAffixModel.item)
    public var affixes: [ItemAffixModel]?

    public init() {}

    public init(item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarityID = item.rarity.rawValue
        displayName = item.displayName
        affixes = item.affixes.enumerated().map { index, affix in
            let model = ItemAffixModel(affix: affix)
            model.sortIndex = index
            return model
        }
    }
}

@Model
public final class ItemAffixModel {
    public var id: String = ""
    public var title: String = ""
    public var affixDescription: String = ""
    public var keywordRawValues: [String] = []
    public var sortIndex: Int = 0
    public var item: InventoryItemModel?

    public init() {}

    public init(affix: ItemAffix) {
        id = affix.id
        title = affix.title
        affixDescription = affix.description
        keywordRawValues = affix.keywords.map(\.rawValue).sorted()
    }
}

@Model
public final class HomesteadModel {
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \HomesteadResourceBalanceModel.homestead)
    public var resources: [HomesteadResourceBalanceModel]?
    @Relationship(deleteRule: .cascade, inverse: \HomesteadNodeTierModel.homestead)
    public var nodeTiers: [HomesteadNodeTierModel]?

    public init() {}
}

@Model
public final class HomesteadResourceBalanceModel {
    public var resourceID: String = ""
    public var quantity: Int = 0
    public var homestead: HomesteadModel?

    public init(resourceID: String = "", quantity: Int = 0) {
        self.resourceID = resourceID
        self.quantity = quantity
    }
}

@Model
public final class HomesteadNodeTierModel {
    public var nodeID: String = ""
    public var tier: Int = 0
    public var homestead: HomesteadModel?

    public init(nodeID: String = "", tier: Int = 0) {
        self.nodeID = nodeID
        self.tier = tier
    }
}

public enum PlayerSaveGraph {
    public static let schema = Schema([
        PlayerSaveRoot.self,
        JourneyProgressModel.self,
        JourneyStageProgressModel.self,
        RosterModel.self,
        UnlockedCombatantModel.self,
        CombatantProgressionModel.self,
        AbilityLoadoutModel.self,
        EquipmentLoadoutModel.self,
        EquipmentSlotModel.self,
        PrimaryStatsModel.self,
        InventoryModel.self,
        InventoryItemModel.self,
        ItemAffixModel.self,
        HomesteadModel.self,
        HomesteadResourceBalanceModel.self,
        HomesteadNodeTierModel.self
    ])
}

public extension PlayerSaveRoot {
    convenience init(save: PlayerSave, id: String = "primary") {
        self.init(id: id)
        update(from: save)
    }

    func toPlayerSave() -> PlayerSave {
        let inventoryState = inventory?.toPlayerInventoryState() ?? .freshStart
        return PlayerSave(
            schemaVersion: schemaVersion,
            modifiedAt: modifiedAt,
            sessionGeneration: sessionGeneration,
            journey: journey?.toJourneyProgressState() ?? .initial,
            roster: roster?.toPlayerRosterState(inventory: inventoryState) ?? .freshStart,
            inventory: inventoryState,
            homestead: homestead?.toPlayerHomesteadState() ?? .freshStart
        )
    }

    func update(from save: PlayerSave) {
        schemaVersion = save.schemaVersion
        modifiedAt = save.modifiedAt
        sessionGeneration = save.sessionGeneration

        syncChild(\.journey, make: JourneyProgressModel()) {
            $0.update(from: save.journey)
        } setRoot: {
            $0.root = self
        }

        syncChild(\.roster, make: RosterModel()) {
            $0.update(from: save.roster)
        } setRoot: {
            $0.root = self
        }

        syncChild(\.inventory, make: InventoryModel()) {
            $0.update(from: save.inventory)
        } setRoot: {
            $0.root = self
        }

        syncChild(\.homestead, make: HomesteadModel()) {
            $0.update(from: save.homestead)
        } setRoot: {
            $0.root = self
        }
    }

    private func syncChild<Model: AnyObject>(
        _ keyPath: ReferenceWritableKeyPath<PlayerSaveRoot, Model?>,
        make: () -> Model,
        update: (Model) -> Void,
        setRoot: (Model) -> Void
    ) {
        let model = self[keyPath: keyPath] ?? make()
        update(model)
        self[keyPath: keyPath] = model
        setRoot(model)
    }
}

private extension JourneyProgressModel {
    func toJourneyProgressState() -> JourneyProgressState {
        let stageModels = stages ?? []
        return JourneyProgressState(
            activeChapterID: activeChapterID,
            activeStageID: activeStageID,
            completedStageIDs: Set(stageModels.filter(\.isCompleted).map(\.stageID)),
            claimedRewardStageIDs: Set(stageModels.filter(\.rewardsClaimed).map(\.stageID)),
            lastCompletedStageID: lastCompletedStageID
        )
    }

    func update(from state: JourneyProgressState) {
        activeChapterID = state.activeChapterID
        activeStageID = state.activeStageID
        lastCompletedStageID = state.lastCompletedStageID
        let allStageIDs = state.completedStageIDs.union(state.claimedRewardStageIDs)
        stages = allStageIDs.sorted().map {
            JourneyStageProgressModel(
                stageID: $0,
                isCompleted: state.completedStageIDs.contains($0),
                rewardsClaimed: state.claimedRewardStageIDs.contains($0)
            )
        }
        stages?.linkEach(to: self, parent: \.journey)
    }
}

private extension RosterModel {
    func toPlayerRosterState(inventory: PlayerInventoryState) -> PlayerRosterState {
        let unlocked = unlockedCombatants ?? []
        let heroIDs = Set(unlocked.filter { $0.role == "hero" }.map(\.combatantID))
        let petIDs = Set(unlocked.filter { $0.role == "pet" }.map(\.combatantID))
        let progressionValues = Dictionary(
            uniqueKeysWithValues: (progressions ?? []).map {
                ($0.combatantID, CombatantProgression(level: $0.level, currentXP: $0.currentXP, requiredXP: $0.requiredXP))
            }
        )
        let wireAbilityValues = Dictionary(
            uniqueKeysWithValues: (abilityLoadouts ?? []).map {
                ($0.combatantID, WireAbilityLoadout(basicID: $0.basicID, skillID: $0.skillID, ultimateID: $0.ultimateID))
            }
        )
        let wireEquipmentValues = Dictionary(
            uniqueKeysWithValues: (equipmentLoadouts ?? []).map {
                ($0.combatantID, WireEquipmentLoadout(itemIDsBySlot: Dictionary(uniqueKeysWithValues: ($0.slots ?? []).map { ($0.slotID, $0.itemID) })))
            }
        )
        let statValues = Dictionary(
            uniqueKeysWithValues: (primaryStats ?? []).map {
                (
                    $0.combatantID,
                    PrimaryStats(
                        strength: $0.strength,
                        agility: $0.agility,
                        toughness: $0.toughness,
                        intellect: $0.intellect,
                        wisdom: $0.wisdom
                    )
                )
            }
        )
        let inventoryItemIDs = Set(inventory.items.map(\.id))
        let (resolvedHeroID, resolvedPetID) = RosterHydration.resolveActiveSelection(
            activeHeroID: activeHeroID,
            activePetID: activePetID,
            unlockedHeroIDs: heroIDs,
            unlockedPetIDs: petIDs
        )

        return PlayerRosterState(
            activeHeroID: resolvedHeroID,
            activePetID: resolvedPetID,
            unlockedHeroIDs: heroIDs,
            unlockedPetIDs: petIDs,
            abilityLoadouts: RosterHydration.resolveAbilityLoadouts(from: wireAbilityValues),
            progressions: progressionValues,
            equipmentLoadouts: RosterHydration.resolveEquipmentLoadouts(
                from: wireEquipmentValues,
                inventoryItemIDs: inventoryItemIDs,
                inventoryItems: inventory.items
            ),
            gold: gold,
            primaryStatOverrides: statValues
        )
    }

    func update(from roster: PlayerRosterState) {
        activeHeroID = roster.activeHeroID
        activePetID = roster.activePetID
        gold = roster.gold

        unlockedCombatants = roster.unlockedHeroIDs.sorted().map { UnlockedCombatantModel(combatantID: $0, role: "hero") }
            + roster.unlockedPetIDs.sorted().map { UnlockedCombatantModel(combatantID: $0, role: "pet") }
        unlockedCombatants?.linkEach(to: self, parent: \.roster)

        progressions = roster.progressions
            .sorted { $0.key < $1.key }
            .map { CombatantProgressionModel(combatantID: $0.key, progression: $0.value) }
        progressions?.linkEach(to: self, parent: \.roster)

        abilityLoadouts = roster.abilityLoadouts
            .sorted { $0.key < $1.key }
            .map { AbilityLoadoutModel(combatantID: $0.key, loadout: $0.value) }
        abilityLoadouts?.linkEach(to: self, parent: \.roster)

        equipmentLoadouts = roster.equipmentLoadouts
            .sorted { $0.key < $1.key }
            .map { combatantID, loadout in
                let model = EquipmentLoadoutModel(combatantID: combatantID)
                model.slots = loadout.itemIDsBySlot
                    .map { EquipmentSlotModel(slotID: $0.key.rawValue, itemID: $0.value) }
                    .sorted { $0.slotID < $1.slotID }
                model.slots?.linkEach(to: model, parent: \.loadout)
                return model
            }
        equipmentLoadouts?.linkEach(to: self, parent: \.roster)

        primaryStats = roster.primaryStatOverrides
            .sorted { $0.key < $1.key }
            .map { PrimaryStatsModel(combatantID: $0.key, stats: $0.value) }
        primaryStats?.linkEach(to: self, parent: \.roster)
    }
}

private extension InventoryModel {
    func toPlayerInventoryState() -> PlayerInventoryState {
        PlayerInventoryState(items: (items ?? [])
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex { return lhs.id < rhs.id }
                return lhs.sortIndex < rhs.sortIndex
            }
            .compactMap { item in
                guard let baseType = GameContent.itemBaseTypes.first(where: { $0.id == item.baseTypeID }) else {
                    return nil
                }
                let affixes = (item.affixes ?? [])
                    .sorted { lhs, rhs in
                        if lhs.sortIndex == rhs.sortIndex { return lhs.id < rhs.id }
                        return lhs.sortIndex < rhs.sortIndex
                    }
                    .compactMap { affix in
                        let keywords = Set(affix.keywordRawValues.compactMap { Keyword(rawValue: $0) })
                        return ItemAffix(
                            id: affix.id,
                            title: affix.title,
                            description: affix.affixDescription,
                            keywords: keywords
                        )
                    }
                return InventoryItem(
                    id: item.id,
                    templateID: item.templateID,
                    baseType: baseType,
                    rarity: Rarity(rawValue: item.rarityID) ?? .basic,
                    displayName: item.displayName,
                    affixes: affixes
                )
            })
    }

    func update(from inventory: PlayerInventoryState) {
        items = inventory.items.enumerated().map { index, item in
            let model = InventoryItemModel(item: item)
            model.sortIndex = index
            return model
        }
        items?.forEach { item in
            item.inventory = self
            item.affixes?.linkEach(to: item, parent: \.item)
        }
    }
}

private extension HomesteadModel {
    func toPlayerHomesteadState() -> PlayerHomesteadState {
        var resolvedResources: [HomesteadResource: Int] = [:]
        for balance in resources ?? [] {
            guard let resource = HomesteadResource(rawValue: balance.resourceID), resource != .gold else { continue }
            resolvedResources[resource] = max(balance.quantity, 0)
        }
        var resolvedNodeTiers: [HomesteadNodeID: Int] = [:]
        for tierModel in nodeTiers ?? [] {
            guard let nodeID = HomesteadNodeID(rawValue: tierModel.nodeID),
                  let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID]
            else { continue }
            resolvedNodeTiers[nodeID] = min(max(tierModel.tier, 0), maxTier)
        }
        return PlayerHomesteadState(resources: resolvedResources, nodeTiers: resolvedNodeTiers)
    }

    func update(from homestead: PlayerHomesteadState) {
        resources = homestead.resources
            .map { HomesteadResourceBalanceModel(resourceID: $0.key.rawValue, quantity: $0.value) }
            .sorted { $0.resourceID < $1.resourceID }
        resources?.linkEach(to: self, parent: \.homestead)
        nodeTiers = homestead.nodeTiers
            .map { HomesteadNodeTierModel(nodeID: $0.key.rawValue, tier: $0.value) }
            .sorted { $0.nodeID < $1.nodeID }
        nodeTiers?.linkEach(to: self, parent: \.homestead)
    }
}

private extension Array {
    func linkEach<Parent>(
        to parent: Parent,
        parent keyPath: ReferenceWritableKeyPath<Element, Parent?>
    ) {
        forEach { $0[keyPath: keyPath] = parent }
    }
}
