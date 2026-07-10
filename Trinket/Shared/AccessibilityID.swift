import Foundation

enum AccessibilityID {
    enum Screen {
        static let play = "Play Screen"
        static let homestead = "Homestead Screen"
        static let options = "Options Screen"
    }

    enum Play {
        static let modesEntry = "Modes Entry"
        static let modesScreen = "Modes Screen"
        static let aspectsHub = "Aspects Hub"
        static let aspectsModeCard = "Aspects Mode Card"
        static let campaignModeCard = "Campaign Mode Card"
        static let battlePartySheet = "Battle Party Sheet"
        static let battlePartyStart = "Battle Party Start"

        static func chapterHeader(number: Int) -> String {
            "Chapter \(number) Header"
        }

        static func stageNode(chapter: Int, stage: Int) -> String {
            "Stage \(chapter)-\(stage) Node"
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

        static func unlockCard(name: String) -> String {
            "\(name) unlock card"
        }
    }

    enum Shop {
        static let encounterTitle = "Shop Encounter Title"
        static let encounterGreeting = "Shop Encounter Greeting"
        static let encounterArt = "Shop Encounter Art"
        static let goldBalance = "Shop Gold Balance"
        static let purchaseConfirmation = "Shop Purchase Confirmation"
        static let leaveButton = "Shop Leave Button"
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
        static let petsCategory = "Pets collection category"
        static let inventoryCategory = "Inventory collection category"
        static let inventoryEmptyState = "Inventory Empty State"
        static let inventoryNoResults = "Inventory No Results"
        static let inventoryFilter = "Inventory filter"
    }

    enum Homestead {
        static func node(title: String) -> String {
            "\(title) Homestead Node"
        }

        static func nodeDetail(title: String) -> String {
            "\(title) Homestead Detail"
        }
    }

    enum Battle {
        static let hand = "Battle Hand"
        static let combatLog = "Combat Log"
        static let retreat = "Retreat"
        static let victory = "Victory"
        static let experience = "Experience"
        static let rewards = "Rewards"
        static let continueButton = "Continue Button"

        static func handCard(_ abilityID: String) -> String {
            "Battle Hand Card \(abilityID)"
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
}
