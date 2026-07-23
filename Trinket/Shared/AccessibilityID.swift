import Foundation
import TrinketContent

enum AccessibilityID {
    enum Screen {
        static let play = "Play Screen"
        static let homestead = "Homestead Screen"
        static let options = "Options Screen"
    }

    enum Debug {
        /// Machine-readable frame-pacing report for performance scenarios (`-enable-frame-metrics`).
        static let frameMetrics = "Frame Metrics"
        static let frameMetricsReset = "Frame Metrics Reset"
        static let battlePerformanceStart = "Battle Performance Start"
        static let battlePerformanceStatus = "Battle Performance Status"
    }

    enum Play {
        static let modesScreen = "Modes Screen"
        static let spiresHub = "Spires Hub"
        static let exploreHub = "Explore Hub"
        static let spiresModeCard = "Spires Mode Card"
        static let campaignModeCard = "Campaign Mode Card"
        static let exploreModeCard = "Explore Mode Card"
        static let battlePartyDone = "Battle Party Done"
        static let chapterPicker = "Campaign Chapter Picker"
        static let activeStageDetail = "Campaign Active Stage Detail"
        static let stagePartyControl = "Campaign Stage Party Control"
        static let stagePartyPickerSheet = "Campaign Stage Party Picker Sheet"

        static func battlePartyShelf(for role: String) -> String {
            "Battle Party \(role) Shelf"
        }

        static func battlePartyOption(for role: String, combatantID: String) -> String {
            "Battle Party \(role) Option \(combatantID)"
        }

        static func chapterHeader(number: Int) -> String {
            "Chapter \(number) Header"
        }

        static func chapterTitle(number: Int) -> String {
            "Chapter \(number) Title"
        }

        static func stageRow(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Row"
        }

        static func stageNode(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Node"
        }

        static func stageAction(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Action"
        }

        static func enemyArt(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Enemy Art"
        }

        static func chapterLocked(number: Int) -> String {
            "Chapter \(number) Locked"
        }

        static func spireRow(_ spireID: String) -> String {
            "Spire \(spireID) Row"
        }

        static func spireClimb(_ spireID: String) -> String {
            "Spire \(spireID) Climb"
        }

        static func spireTitle(_ spireID: String) -> String {
            "Spire \(spireID) Title"
        }

        static func spireFloor(_ spireID: String, floor: Int) -> String {
            "Spire \(spireID) Floor \(floor)"
        }

        static func spireBeginFloor(_ spireID: String, floor: Int) -> String {
            "Spire \(spireID) Begin Floor \(floor)"
        }

        static func spireFloorEnemyArt(_ spireID: String, floor: Int) -> String {
            "Spire \(spireID) Floor \(floor) Enemy Art"
        }

        static func spireActiveFloorDetail(_ spireID: String) -> String {
            "Spire \(spireID) Active Floor Detail"
        }

        static func spirePartyControl(_ spireID: String) -> String {
            "Spire \(spireID) Party Control"
        }

        static func spirePartyPickerSheet(_ spireID: String) -> String {
            "Spire \(spireID) Party Picker Sheet"
        }

        static func spireCompletionBack(_ spireID: String) -> String {
            "Spire \(spireID) Completion Back"
        }

        static let labyrinthModeCard = "Labyrinth Mode Card"
        static let labyrinthMap = "Labyrinth Map"
        static let labyrinthEnter = "Labyrinth Enter"
        static let labyrinthRest = "Labyrinth Rest"
        static let labyrinthRestConfirm = "Labyrinth Rest Confirm"
        static let labyrinthRestLeave = "Labyrinth Rest Leave"
        static let labyrinthRestFailure = "Labyrinth Rest Failure"
        static let labyrinthCraft = "Labyrinth Craft"
        static let labyrinthCraftForge = "Labyrinth Craft Forge"
        static let labyrinthCraftSkip = "Labyrinth Craft Skip"
        static let labyrinthCraftLeave = "Labyrinth Craft Leave"
        static let labyrinthCraftFailure = "Labyrinth Craft Failure"
        static let labyrinthFloorMenu = "Labyrinth Floor Menu"
        static let labyrinthNodeInspector = "Labyrinth Node Inspector"

        static func labyrinthFloor(_ floor: Int) -> String {
            "Labyrinth Floor \(floor)"
        }

        static func labyrinthNode(_ nodeID: String) -> String {
            "Labyrinth Node \(nodeID)"
        }

        static func labyrinthNodeArtwork(_ nodeID: String) -> String {
            "Labyrinth Node \(nodeID) Artwork"
        }

        static func labyrinthInspectorAction(_ nodeID: String) -> String {
            "Labyrinth Inspector Action \(nodeID)"
        }
    }

    enum Mystery {
        static let encounterTitle = "Mystery Encounter Title"
        static let encounterNarrative = "Mystery Encounter Narrative"
        static let rewardTitle = "Mystery Reward Title"
        static let unlockEyebrow = "Mystery Unlock Eyebrow"
        static let unlockName = "Mystery Unlock Name"
        static let unlockSubtitle = "Mystery Unlock Subtitle"
        static let continueButton = "Mystery Continue Button"
        static let confirmChoiceButton = "Mystery Confirm Choice Button"
        static let chooseItemTitle = "Mystery Choose Item Title"
        static let persistFailure = "Mystery Persist Failure"

        static func unlockCard(name: String) -> String {
            "\(name) unlock card"
        }

        static func choiceButton(choiceID: String) -> String {
            "Mystery Choice \(choiceID)"
        }

        static func chooseItemCard(itemID: String) -> String {
            "Mystery Choose Item \(itemID)"
        }
    }

    enum Shop {
        static let encounterTitle = "Shop Encounter Title"
        static let encounterGreeting = "Shop Encounter Greeting"
        static let encounterArt = "Shop Encounter Art"
        static let goldBalance = "Shop Gold Balance"
        static let leaveButton = "Shop Leave Button"
        static let leaveFailure = "Shop Leave Failure"
        static let detailBuyButton = "Shop Detail Buy Button"
        static let purchaseError = "Shop Purchase Error"

        static func offerCard(offerID: String) -> String {
            "\(offerID) shop offer"
        }

        static func buyButton(offerID: String) -> String {
            "Buy \(offerID)"
        }
    }

    enum CombatantDetail {
        static let statsSection = "Combatant Stats Section"
        static let healthStat = "Combatant Health Stat"
        static let traitSection = "Combatant Trait Section"
        static let traitDescription = "Combatant Trait Description"
        static let enemyTraitsSection = "Combatant Enemy Traits Section"
        static let enemyTraitDescription = "Combatant Enemy Trait Description"

        static func header(name: String) -> String {
            "\(name) detail hero header"
        }

        static func collectionCard(name: String) -> String {
            "\(name) collection card"
        }

        static func battleCard(name: String) -> String {
            "\(name) card"
        }
    }

    enum Collection {
        static let heroesCategory = "Heroes collection category"
        static let companionsCategory = "Companions collection category"
        static let inventoryCategory = "Inventory collection category"
        static let inventoryEmptyState = "Inventory Empty State"
        static let inventoryNoResults = "Inventory No Results"
        static let inventoryFilter = "Inventory filter"
    }

    enum Homestead {
        static let resourceWallet = "Homestead Resource Wallet"
        static let tierPath = "Homestead Tier Path"

        static func category(_ title: String) -> String {
            "Homestead \(title) Category"
        }

        static func node(title: String) -> String {
            "\(title) Homestead Node"
        }

        static func nodeDetail(title: String) -> String {
            "\(title) Homestead Detail"
        }

        static func tierNode(title: String, tier: Int) -> String {
            "\(title) Homestead Tier \(tier)"
        }
    }

    enum Battle {
        static let actionsMenu = "Battle Actions"
        static let hand = "Battle Hand"
        static let combatLog = "Combat Log"
        #if DEBUG
        static let skipCombat = "Skip Combat"
        #endif
        static let retreat = "Retreat"
        static let victory = "Victory"
        static let experience = "Experience"
        static let rewards = "Rewards"
        static let continueButton = "Continue Button"
        static let abilityDetail = "Battle Ability Detail"
        static let abilityDetailEffect = "Battle Ability Detail Effect"

        static func handCard(_ abilityID: String) -> String {
            "Battle Hand Card \(abilityID)"
        }

        static func rewardItem(_ itemID: String) -> String {
            "Victory Reward Item \(itemID)"
        }
    }

    enum Equipment {
        static let basicAbilitySlot = "Basic ability slot"
    }

    enum LoadoutPicker {
        static func abilityGrid(_ tier: String) -> String {
            "Loadout Ability Grid \(tier)"
        }

        static func abilityCandidate(_ abilityID: String) -> String {
            "Loadout Ability Candidate \(abilityID)"
        }

        static func abilityDetail(_ abilityID: String) -> String {
            "Loadout Ability Detail \(abilityID)"
        }

        static func selectAbility(_ abilityID: String) -> String {
            "Select Loadout Ability \(abilityID)"
        }

        static func itemGrid(_ slot: String) -> String {
            "Loadout Item Grid \(slot)"
        }

        static func itemCandidate(_ itemID: String) -> String {
            "Loadout Item Candidate \(itemID)"
        }

        static func itemDetail(_ itemID: String) -> String {
            "Loadout Item Detail \(itemID)"
        }

        static func equipItem(_ itemID: String) -> String {
            "Equip Loadout Item \(itemID)"
        }
    }
}
