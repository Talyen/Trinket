import Foundation
import TrinketContent

public enum AccessibilityID {
    public enum Screen {
        public static let play = "Play Screen"
        public static let homestead = "Homestead Screen"
        public static let options = "Options Screen"
    }

    public enum Debug {
        /// Machine-readable frame-pacing report for performance scenarios (`-enable-frame-metrics`).
        public static let frameMetrics = "Frame Metrics"
        public static let frameMetricsReset = "Frame Metrics Reset"
        public static let battlePerformanceStart = "Battle Performance Start"
        public static let battlePerformanceStatus = "Battle Performance Status"
    }

    public enum Play {
        public static let modesScreen = "Modes Screen"
        public static let spiresHub = "Spires Hub"
        public static let exploreHub = "Explore Hub"
        public static let spiresModeCard = "Spires Mode Card"
        public static let campaignModeCard = "Campaign Mode Card"
        public static let exploreModeCard = "Explore Mode Card"
        public static let battlePartyDone = "Battle Party Done"
        public static let activeStageDetail = "Campaign Active Stage Detail"
        public static let stagePartyControl = "Campaign Stage Party Control"
        public static let stagePartyPickerSheet = "Campaign Stage Party Picker Sheet"

        public static func battlePartyShelf(for role: String) -> String {
            "Battle Party \(role) Shelf"
        }

        public static func battlePartyOption(for role: String, combatantID: String) -> String {
            "Battle Party \(role) Option \(combatantID)"
        }

        public static func chapterHeader(number: Int) -> String {
            "Chapter \(number) Header"
        }

        public static func chapterTitle(number: Int) -> String {
            "Chapter \(number) Title"
        }

        public static func stageRow(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Row"
        }

        public static func stageAction(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Action"
        }

        public static func enemyArt(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Enemy Art"
        }

        public static func spireRow(_ spireID: String) -> String {
            "Spire \(spireID) Row"
        }

        public static func spireClimb(_ spireID: String) -> String {
            "Spire \(spireID) Climb"
        }

        public static func spireTitle(_ spireID: String) -> String {
            "Spire \(spireID) Title"
        }

        public static func spireFloor(_ spireID: String, floor: Int) -> String {
            "Spire \(spireID) Floor \(floor)"
        }

        public static func spireBeginFloor(_ spireID: String, floor: Int) -> String {
            "Spire \(spireID) Begin Floor \(floor)"
        }

        public static func spireFloorEnemyArt(_ spireID: String, floor: Int) -> String {
            "Spire \(spireID) Floor \(floor) Enemy Art"
        }

        public static func spireActiveFloorDetail(_ spireID: String) -> String {
            "Spire \(spireID) Active Floor Detail"
        }

        public static func spirePartyControl(_ spireID: String) -> String {
            "Spire \(spireID) Party Control"
        }

        public static func spirePartyPickerSheet(_ spireID: String) -> String {
            "Spire \(spireID) Party Picker Sheet"
        }

        public static func spireCompletionBack(_ spireID: String) -> String {
            "Spire \(spireID) Completion Back"
        }

        public static let campaignCompletionBack = "Campaign Completion Back"

        public static let labyrinthModeCard = "Labyrinth Mode Card"
        public static let labyrinthMap = "Labyrinth Map"
        public static let labyrinthEnter = "Labyrinth Enter"
        public static let labyrinthRest = "Labyrinth Rest"
        public static let labyrinthRestConfirm = "Labyrinth Rest Confirm"
        public static let labyrinthRestLeave = "Labyrinth Rest Leave"
        public static let labyrinthRestFailure = "Labyrinth Rest Failure"
        public static let labyrinthCraft = "Labyrinth Craft"
        public static let labyrinthCraftForge = "Labyrinth Craft Forge"
        public static let labyrinthCraftSkip = "Labyrinth Craft Skip"
        public static let labyrinthCraftLeave = "Labyrinth Craft Leave"
        public static let labyrinthCraftFailure = "Labyrinth Craft Failure"
        public static let labyrinthFloorMenu = "Labyrinth Floor Menu"
        public static let labyrinthNodeInspector = "Labyrinth Node Inspector"

        public static func labyrinthFloor(_ floor: Int) -> String {
            "Labyrinth Floor \(floor)"
        }

        public static func labyrinthNode(_ nodeID: String) -> String {
            "Labyrinth Node \(nodeID)"
        }

        public static func labyrinthNodeArtwork(_ nodeID: String) -> String {
            "Labyrinth Node \(nodeID) Artwork"
        }

        public static func labyrinthInspectorAction(_ nodeID: String) -> String {
            "Labyrinth Inspector Action \(nodeID)"
        }
    }

    public enum Mystery {
        public static let encounterTitle = "Mystery Encounter Title"
        public static let encounterNarrative = "Mystery Encounter Narrative"
        public static let rewardTitle = "Mystery Reward Title"
        public static let unlockEyebrow = "Mystery Unlock Eyebrow"
        public static let unlockName = "Mystery Unlock Name"
        public static let unlockSubtitle = "Mystery Unlock Subtitle"
        public static let continueButton = "Mystery Continue Button"
        public static let confirmChoiceButton = "Mystery Confirm Choice Button"
        public static let persistFailure = "Mystery Persist Failure"
        public static let corruptItemTitle = "Mystery Corrupt Item Title"
        public static let corruptCancelButton = "Mystery Corrupt Cancel Button"
        public static let corruptionRevealTitle = "Mystery Corruption Reveal Title"
        public static let corruptionContinueButton = "Mystery Corruption Continue Button"

        public static func unlockCard(name: String) -> String {
            "\(name) unlock card"
        }

        public static func choiceButton(choiceID: String) -> String {
            "Mystery Choice \(choiceID)"
        }

        public static func corruptItemCard(itemID: String) -> String {
            "Mystery Corrupt Item \(itemID)"
        }
    }

    public enum Shop {
        public static let encounterTitle = "Shop Encounter Title"
        public static let encounterGreeting = "Shop Encounter Greeting"
        public static let encounterArt = "Shop Encounter Art"
        public static let goldBalance = "Shop Gold Balance"
        public static let leaveButton = "Shop Leave Button"
        public static let leaveFailure = "Shop Leave Failure"
        public static let detailBuyButton = "Shop Detail Buy Button"
        public static let purchaseError = "Shop Purchase Error"

        public static func offerCard(offerID: String) -> String {
            "\(offerID) shop offer"
        }

        public static func buyButton(offerID: String) -> String {
            "Buy \(offerID)"
        }
    }

    public enum CombatantDetail {
        public static let statsSection = "Combatant Stats Section"
        public static let healthStat = "Combatant Health Stat"
        public static let traitSection = "Combatant Trait Section"
        public static let traitDescription = "Combatant Trait Description"
        public static let enemyTraitsSection = "Combatant Enemy Traits Section"
        public static let enemyTraitDescription = "Combatant Enemy Trait Description"
        public static let labyrinthModifiersSection = "Combatant Labyrinth Modifiers Section"
        public static let labyrinthModifierDescription = "Combatant Labyrinth Modifier Description"

        public static func header(name: String) -> String {
            "\(name) detail hero header"
        }

        public static func collectionCard(name: String) -> String {
            "\(name) collection card"
        }

        public static func battleCard(name: String) -> String {
            "\(name) card"
        }
    }

    public enum Collection {
        public static let heroesCategory = "Heroes collection category"
        public static let companionsCategory = "Companions collection category"
        public static let inventoryCategory = "Inventory collection category"
        public static let inventoryEmptyState = "Inventory Empty State"
        public static let inventoryNoResults = "Inventory No Results"
        public static let inventoryFilter = "Inventory filter"
        public static let salvageButton = "Salvage Item Button"
        public static let salvageConfirmButton = "Confirm Salvage Button"
    }

    public enum Homestead {
        public static let resourceWallet = "Homestead Resource Wallet"
        public static let collectButton = "Homestead Collect Button"
        public static let tierPath = "Homestead Tier Path"

        public static func category(_ title: String) -> String {
            "Homestead \(title) Category"
        }

        public static func node(title: String) -> String {
            "\(title) Homestead Node"
        }

        public static func nodeDetail(title: String) -> String {
            "\(title) Homestead Detail"
        }

        public static func tierNode(title: String, tier: Int) -> String {
            "\(title) Homestead Tier \(tier)"
        }
    }

    public enum Battle {
        public static let actionsMenu = "Battle Actions"
        public static let autoBattleToggle = "Auto Battle Toggle"
        public static let hand = "Battle Hand"
        public static let combatLog = "Combat Log"
        #if DEBUG
        public static let skipCombat = "Skip Combat"
        #endif
        public static let retreat = "Retreat"
        public static let victory = "Victory"
        public static let experience = "Experience"
        public static let rewards = "Rewards"
        public static let continueButton = "Continue Button"
        public static let abilityDetail = "Battle Ability Detail"
        public static let abilityDetailEffect = "Battle Ability Detail Effect"

        public static func handCard(_ abilityID: String) -> String {
            "Battle Hand Card \(abilityID)"
        }

        public static func rewardItem(_ itemID: String) -> String {
            "Victory Reward Item \(itemID)"
        }
    }

    public enum Equipment {
        public static let basicAbilitySlot = "Basic ability slot"
    }

    public enum LoadoutPicker {
        public static func abilityGrid(_ tier: String) -> String {
            "Loadout Ability Grid \(tier)"
        }

        public static func abilityCandidate(_ abilityID: String) -> String {
            "Loadout Ability Candidate \(abilityID)"
        }

        public static func abilityDetail(_ abilityID: String) -> String {
            "Loadout Ability Detail \(abilityID)"
        }

        public static func selectAbility(_ abilityID: String) -> String {
            "Select Loadout Ability \(abilityID)"
        }

        public static func itemGrid(_ slot: String) -> String {
            "Loadout Item Grid \(slot)"
        }

        public static func itemCandidate(_ itemID: String) -> String {
            "Loadout Item Candidate \(itemID)"
        }

        public static func itemDetail(_ itemID: String) -> String {
            "Loadout Item Detail \(itemID)"
        }

        public static func equipItem(_ itemID: String) -> String {
            "Equip Loadout Item \(itemID)"
        }
    }
}
