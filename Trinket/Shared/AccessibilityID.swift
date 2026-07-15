import Foundation

enum AccessibilityID {
    enum Screen {
        static let play = "Play Screen"
        static let homestead = "Homestead Screen"
        static let options = "Options Screen"
    }

    enum Debug {
        /// Machine-readable frame-pacing report for performance scenarios (`-enable-frame-metrics`).
        static let frameMetrics = "Frame Metrics"
        static let battlePerformanceStart = "Battle Performance Start"
        static let battlePerformanceStatus = "Battle Performance Status"
    }

    enum Play {
        static let modesEntry = "Modes Entry"
        static let modesScreen = "Modes Screen"
        static let aspectsHub = "Aspects Hub"
        static let exploreHub = "Explore Hub"
        static let aspectsModeCard = "Aspects Mode Card"
        static let campaignModeCard = "Campaign Mode Card"
        static let exploreModeCard = "Explore Mode Card"
        static let battlePartyInlinePicker = "Battle Party Inline Picker"
        static let battlePartyHeroControl = "Battle Party Hero Control"
        static let battlePartyCompanionControl = "Battle Party Companion Control"
        static let chapterPicker = "Campaign Chapter Picker"
        static let chapterAdvance = "Campaign Chapter Advance"
        static let stageRewards = "Campaign Stage Rewards"
        static let activeStageDetail = "Campaign Active Stage Detail"
        static let stagePartyControl = "Campaign Stage Party Control"
        static let stagePartyPickerSheet = "Campaign Stage Party Picker Sheet"

        static func battlePartyPickerSheet(for role: String) -> String {
            "Battle Party \(role) Picker Sheet"
        }

        static func battlePartyOption(for role: String, combatantName: String) -> String {
            "Battle Party \(role) Option \(combatantName)"
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

        static func bossBadge(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Boss Badge"
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

        static func aspectRow(_ aspectID: String) -> String {
            "Aspect \(aspectID) Row"
        }

        static func aspectClimb(_ aspectID: String) -> String {
            "Aspect \(aspectID) Climb"
        }

        static func aspectFloor(_ aspectID: String, floor: Int) -> String {
            "Aspect \(aspectID) Floor \(floor)"
        }

        static let labyrinthModeCard = "Labyrinth Mode Card"
        static let labyrinthMap = "Labyrinth Map"
        static let labyrinthAtlas = "Labyrinth Atlas"
        static let labyrinthEnter = "Labyrinth Enter"
        static let labyrinthLeave = "Labyrinth Leave"
        static let labyrinthRest = "Labyrinth Rest"
        static let labyrinthRestConfirm = "Labyrinth Rest Confirm"
        static let labyrinthRestLeave = "Labyrinth Rest Leave"
        static let labyrinthRestFailure = "Labyrinth Rest Failure"
        static let labyrinthCraft = "Labyrinth Craft"
        static let labyrinthCraftForge = "Labyrinth Craft Forge"
        static let labyrinthCraftSkip = "Labyrinth Craft Skip"
        static let labyrinthCraftLeave = "Labyrinth Craft Leave"
        static let labyrinthCraftFailure = "Labyrinth Craft Failure"
        static let labyrinthDepthBadge = "Labyrinth Depth Badge"

        static func labyrinthNode(_ nodeID: String) -> String {
            "Labyrinth Node \(nodeID)"
        }

        static func labyrinthModifier(_ modifierID: String) -> String {
            "Labyrinth Modifier \(modifierID)"
        }

        static func labyrinthFogNode(_ nodeID: String) -> String {
            "Labyrinth Fog \(nodeID)"
        }
    }

    enum Mystery {
        static let encounterTitle = "Mystery Encounter Title"
        static let encounterNarrative = "Mystery Encounter Narrative"
        static let welcomeButton = "Mystery Welcome Button"
        static let unlockEyebrow = "Mystery Unlock Eyebrow"
        static let unlockName = "Mystery Unlock Name"
        static let unlockSubtitle = "Mystery Unlock Subtitle"
        static let continueButton = "Mystery Continue Button"
        static let chooseItemTitle = "Mystery Choose Item Title"

        static func unlockCard(name: String) -> String {
            "\(name) unlock card"
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
        static let purchaseConfirmation = "Shop Purchase Confirmation"
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

        static func footerAction(title: String) -> String {
            "\(title) Homestead Action"
        }
    }

    enum Battle {
        static let actionsMenu = "Battle Actions"
        static let hand = "Battle Hand"
        static let combatLog = "Combat Log"
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
        static let weaponSlot = "Weapon item slot"
        static let armorSlot = "Armor item slot"
        static let trinketSlot = "Trinket item slot"
        static let findWeaponToUnlock = "Find a Weapon to Unlock"
        static let findArmorToUnlock = "Find Armor to Unlock"
        static let findTrinketToUnlock = "Find a Trinket to Unlock"
        static let equipWeapon = "Equip Weapon"
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
