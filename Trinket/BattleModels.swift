import Foundation

enum GameMode: String, CaseIterable, Identifiable {
    case battle = "Battle"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .battle:
            return "Choose a Hero and Pet, then test simple Keyword abilities against an enemy."
        }
    }
}

enum Keyword: String, CaseIterable, Identifiable, Hashable {
    case physical = "Physical"
    case burn = "Burn"

    var id: String { rawValue }

    var rulesText: String {
        switch self {
        case .physical:
            return "Direct weapon or body damage."
        case .burn:
            return "Damage over time on the enemy."
        }
    }
}

enum AbilityTier: String, CaseIterable, Identifiable, Hashable {
    case basic = "Basic"
    case skill = "Skill"
    case ultimate = "Ultimate"

    var id: String { rawValue }

    var cadenceTurns: Int {
        switch self {
        case .basic:
            return 1
        case .skill:
            return 3
        case .ultimate:
            return 6
        }
    }
}

struct StatusApplication: Hashable {
    let keyword: Keyword
    let durationTicks: Int
    let tickDamage: Int

    var summary: String {
        "\(keyword.rawValue) \(tickDamage) for \(durationTicks) ticks"
    }
}

struct ActiveStatus: Identifiable, Equatable, Hashable {
    let id: Int
    let keyword: Keyword
    var remainingTicks: Int
    let tickDamage: Int

    var summary: String {
        "\(remainingTicks) ticks remaining, \(tickDamage) damage each tick"
    }
}

struct StatusSummary: Identifiable, Equatable {
    let keyword: Keyword
    let stackCount: Int
    let totalTickDamage: Int

    var id: Keyword { keyword }

    var text: String {
        "\(keyword.rawValue): \(totalTickDamage) damage next tick, \(stackCount) \(stackCount == 1 ? "stack" : "stacks")."
    }
}

struct Ability: Identifiable, Hashable {
    let id: String
    let name: String
    let tier: AbilityTier
    let directDamage: Int
    let damageKeyword: Keyword
    let statusApplication: StatusApplication?

    static let strike = Ability(
        id: "strike",
        name: "Strike",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let shieldJab = Ability(
        id: "shield-jab",
        name: "Shield Jab",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let quickCut = Ability(
        id: "quick-cut",
        name: "Quick Cut",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let ember = Ability(
        id: "ember",
        name: "Ember",
        tier: .basic,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 2, tickDamage: 1)
    )

    static let smite = Ability(
        id: "smite",
        name: "Smite",
        tier: .skill,
        directDamage: 3,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let guardingBlow = Ability(
        id: "guarding-blow",
        name: "Guarding Blow",
        tier: .skill,
        directDamage: 2,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let firebolt = Ability(
        id: "firebolt",
        name: "Firebolt",
        tier: .skill,
        directDamage: 3,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 2, tickDamage: 1)
    )

    static let kindle = Ability(
        id: "kindle",
        name: "Kindle",
        tier: .skill,
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 3, tickDamage: 2)
    )

    static let radiantCrash = Ability(
        id: "radiant-crash",
        name: "Radiant Crash",
        tier: .ultimate,
        directDamage: 6,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let oathbreaker = Ability(
        id: "oathbreaker",
        name: "Oathbreaker",
        tier: .ultimate,
        directDamage: 5,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let meteor = Ability(
        id: "meteor",
        name: "Meteor",
        tier: .ultimate,
        directDamage: 6,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 3, tickDamage: 2)
    )

    static let inferno = Ability(
        id: "inferno",
        name: "Inferno",
        tier: .ultimate,
        directDamage: 4,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 3, tickDamage: 3)
    )

    var damage: Int {
        directDamage
    }

    var damageType: Keyword {
        damageKeyword
    }

    var keywords: [Keyword] {
        var result = [damageKeyword]
        if let statusApplication {
            result.append(statusApplication.keyword)
        }
        return result
    }

    var summary: String {
        if let statusApplication {
            return "\(directDamage) \(damageKeyword.rawValue) damage. Apply \(statusApplication.summary)."
        }

        return "\(directDamage) \(damageKeyword.rawValue) damage"
    }
}

struct AbilityLoadout: Hashable {
    let basic: Ability?
    let skill: Ability?
    let ultimate: Ability?

    init(
        basic: Ability? = nil,
        skill: Ability? = nil,
        ultimate: Ability? = nil
    ) {
        self.basic = basic
        self.skill = skill
        self.ultimate = ultimate
    }

    var abilities: [Ability] {
        [basic, skill, ultimate].compactMap { $0 }
    }

    func ability(for tier: AbilityTier) -> Ability? {
        switch tier {
        case .basic:
            return basic
        case .skill:
            return skill
        case .ultimate:
            return ultimate
        }
    }

    func selecting(_ ability: Ability) -> AbilityLoadout {
        switch ability.tier {
        case .basic:
            return AbilityLoadout(basic: ability, skill: skill, ultimate: ultimate)
        case .skill:
            return AbilityLoadout(basic: basic, skill: ability, ultimate: ultimate)
        case .ultimate:
            return AbilityLoadout(basic: basic, skill: skill, ultimate: ability)
        }
    }
}

struct CombatantProgression: Equatable, Hashable {
    let level: Int
    let currentXP: Int
    let requiredXP: Int

    static let initial = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

    var progressFraction: Double {
        guard requiredXP > 0 else { return 0 }
        return min(max(Double(currentXP) / Double(requiredXP), 0), 1)
    }
}

enum ItemSlot: String, CaseIterable, Identifiable, Hashable {
    case weapon = "Weapon"
    case armor = "Armor"
    case trinket = "Trinket"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .weapon:
            return "wand.and.sparkles"
        case .armor:
            return "shield.fill"
        case .trinket:
            return "diamond.fill"
        }
    }
}

struct ItemBaseType: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let slot: ItemSlot
    let symbolName: String
}

struct ItemAffix: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let description: String
}

struct InventoryItem: Identifiable, Equatable, Hashable {
    let id: String
    let baseType: ItemBaseType
    let displayName: String
    let affixes: [ItemAffix]
}

struct EquipmentLoadout: Equatable, Hashable {
    var itemIDsBySlot: [ItemSlot: String]

    init(itemIDsBySlot: [ItemSlot: String] = [:]) {
        self.itemIDsBySlot = itemIDsBySlot
    }

    func itemID(for slot: ItemSlot) -> String? {
        itemIDsBySlot[slot]
    }

    mutating func equip(_ item: InventoryItem, in slot: ItemSlot? = nil) {
        itemIDsBySlot[slot ?? item.baseType.slot] = item.id
    }

    mutating func unequip(_ slot: ItemSlot) {
        itemIDsBySlot[slot] = nil
    }
}

struct PlayerInventoryState: Equatable {
    var items: [InventoryItem]

    static var initial: PlayerInventoryState {
        PlayerInventoryState(items: GameContent.sampleInventoryItems)
    }

    func item(matching id: String?) -> InventoryItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    func items(for slot: ItemSlot) -> [InventoryItem] {
        items.filter { $0.baseType.slot == slot }
    }
}

struct AbilityChoices: Hashable {
    let basics: [Ability]
    let skills: [Ability]
    let ultimates: [Ability]
    let selected: AbilityLoadout

    init(
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability],
        selected: AbilityLoadout? = nil
    ) {
        self.basics = basics
        self.skills = skills
        self.ultimates = ultimates
        let defaultLoadout = AbilityLoadout(
            basic: basics.first,
            skill: skills.first,
            ultimate: ultimates.first
        )
        self.selected = AbilityChoices.resolvedLoadout(
            selected ?? defaultLoadout,
            basics: basics,
            skills: skills,
            ultimates: ultimates
        )
    }

    init(abilities: [Ability]) {
        self.init(
            basics: abilities.filter { $0.tier == .basic },
            skills: abilities.filter { $0.tier == .skill },
            ultimates: abilities.filter { $0.tier == .ultimate }
        )
    }

    func abilities(for tier: AbilityTier) -> [Ability] {
        switch tier {
        case .basic:
            return basics
        case .skill:
            return skills
        case .ultimate:
            return ultimates
        }
    }

    func withSelectedLoadout(_ loadout: AbilityLoadout) -> AbilityChoices {
        AbilityChoices(
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            selected: loadout
        )
    }

    private static func resolvedLoadout(
        _ loadout: AbilityLoadout,
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability]
    ) -> AbilityLoadout {
        AbilityLoadout(
            basic: selectedAbility(loadout.basic, in: basics),
            skill: selectedAbility(loadout.skill, in: skills),
            ultimate: selectedAbility(loadout.ultimate, in: ultimates)
        )
    }

    private static func selectedAbility(_ ability: Ability?, in choices: [Ability]) -> Ability? {
        guard let ability else {
            return choices.first
        }

        return choices.first { $0.id == ability.id } ?? choices.first
    }
}

struct Combatant: Identifiable, Hashable {
    enum Role: String {
        case hero = "Hero"
        case pet = "Pet"
        case enemy = "Enemy"
    }

    let id: String
    let name: String
    let role: Role
    let maxHealth: Int
    let abilityChoices: AbilityChoices

    init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        abilityChoices: AbilityChoices
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.maxHealth = maxHealth
        self.abilityChoices = abilityChoices
    }

    init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        abilities: [Ability]
    ) {
        self.init(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            abilityChoices: AbilityChoices(abilities: abilities)
        )
    }

    var abilityLoadout: AbilityLoadout {
        abilityChoices.selected
    }

    var abilities: [Ability] {
        abilityLoadout.abilities
    }

    func withAbilityLoadout(_ loadout: AbilityLoadout) -> Combatant {
        Combatant(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            abilityChoices: abilityChoices.withSelectedLoadout(loadout)
        )
    }
}

struct PlayerRosterState: Equatable {
    var activeHeroID: String
    var activePetID: String
    var abilityLoadouts: [String: AbilityLoadout]
    var progressions: [String: CombatantProgression]
    var equipmentLoadouts: [String: EquipmentLoadout]

    static var initial: PlayerRosterState {
        PlayerRosterState(
            activeHeroID: GameContent.heroes.first?.id ?? "",
            activePetID: GameContent.pets.first?.id ?? "",
            abilityLoadouts: [:],
            progressions: [
                "paladin": CombatantProgression(level: 2, currentXP: 35, requiredXP: 120),
                "rogue": CombatantProgression(level: 1, currentXP: 65, requiredXP: 100),
                "mage": CombatantProgression(level: 3, currentXP: 20, requiredXP: 160),
                "wolf": CombatantProgression(level: 2, currentXP: 12, requiredXP: 100),
                "hawk": CombatantProgression(level: 1, currentXP: 40, requiredXP: 100),
                "drake": CombatantProgression(level: 3, currentXP: 90, requiredXP: 180)
            ],
            equipmentLoadouts: [
                "paladin": EquipmentLoadout(itemIDsBySlot: [
                    .weapon: "ember-wand",
                    .armor: "leather-gloves",
                    .trinket: "river-charm"
                ]),
                "mage": EquipmentLoadout(itemIDsBySlot: [
                    .weapon: "ember-wand",
                    .trinket: "river-charm"
                ]),
                "wolf": EquipmentLoadout(itemIDsBySlot: [
                    .armor: "leather-gloves"
                ])
            ]
        )
    }

    func loadout(for combatant: Combatant) -> AbilityLoadout {
        abilityLoadouts[combatant.id] ?? combatant.abilityLoadout
    }

    mutating func setLoadout(_ loadout: AbilityLoadout, for combatant: Combatant) {
        let configuredCombatant = combatant.withAbilityLoadout(loadout)
        abilityLoadouts[combatant.id] = configuredCombatant.abilityLoadout
    }

    func configuredCombatant(_ combatant: Combatant) -> Combatant {
        combatant.withAbilityLoadout(loadout(for: combatant))
    }

    func configuredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        combatants.map(configuredCombatant)
    }

    func progression(for combatant: Combatant) -> CombatantProgression {
        progressions[combatant.id] ?? .initial
    }

    func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        equipmentLoadouts[combatant.id] ?? EquipmentLoadout()
    }

    mutating func setEquipmentLoadout(_ loadout: EquipmentLoadout, for combatant: Combatant) {
        equipmentLoadouts[combatant.id] = loadout
    }

    func equippedItem(
        for slot: ItemSlot,
        combatant: Combatant,
        inventory: PlayerInventoryState
    ) -> InventoryItem? {
        inventory.item(matching: equipmentLoadout(for: combatant).itemID(for: slot))
    }
}

enum GameContent {
    static let itemBaseTypes = [
        ItemBaseType(
            id: "ember-wand",
            name: "Ember Wand",
            slot: .weapon,
            symbolName: "wand.and.sparkles"
        ),
        ItemBaseType(
            id: "leather-gloves",
            name: "Leather Gloves",
            slot: .armor,
            symbolName: "hands.sparkles.fill"
        ),
        ItemBaseType(
            id: "river-charm",
            name: "River Charm",
            slot: .trinket,
            symbolName: "drop.fill"
        ),
        ItemBaseType(
            id: "iron-sword",
            name: "Iron Sword",
            slot: .weapon,
            symbolName: "sword.fill"
        )
    ]

    static let sampleInventoryItems = [
        InventoryItem(
            id: "ember-wand",
            baseType: itemBaseTypes[0],
            displayName: "Kindled Ember Wand",
            affixes: [
                ItemAffix(id: "ember-wand-affix-1", title: "Warm Focus", description: "+3% fire-themed ability power."),
                ItemAffix(id: "ember-wand-affix-2", title: "Bright Edge", description: "Basic attacks feel slightly sharper."),
                ItemAffix(id: "ember-wand-affix-3", title: "Cinder Memory", description: "A reminder that item effects are visual-only for now.")
            ]
        ),
        InventoryItem(
            id: "leather-gloves",
            baseType: itemBaseTypes[1],
            displayName: "Patient Leather Gloves",
            affixes: [
                ItemAffix(id: "leather-gloves-affix-1", title: "Steady Grip", description: "+2 placeholder handling."),
                ItemAffix(id: "leather-gloves-affix-2", title: "Soft Stitching", description: "Comfortable enough for long idle battles.")
            ]
        ),
        InventoryItem(
            id: "river-charm",
            baseType: itemBaseTypes[2],
            displayName: "River Charm of Sparks",
            affixes: [
                ItemAffix(id: "river-charm-affix-1", title: "Lucky Current", description: "+1 placeholder luck."),
                ItemAffix(id: "river-charm-affix-2", title: "Blue Glimmer", description: "Adds a cool-toned visual identity."),
                ItemAffix(id: "river-charm-affix-3", title: "Polished Loop", description: "Fits the shared Trinket slot."),
                ItemAffix(id: "river-charm-affix-4", title: "Quiet Weight", description: "No combat effect is applied yet.")
            ]
        ),
        InventoryItem(
            id: "iron-sword",
            baseType: itemBaseTypes[3],
            displayName: "Plain Iron Sword",
            affixes: [
                ItemAffix(id: "iron-sword-affix-1", title: "Reliable", description: "A clean baseline weapon for layout testing.")
            ]
        )
    ]

    static let heroes = [
        Combatant(
            id: "paladin",
            name: "Paladin",
            role: .hero,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.strike, .shieldJab],
                skills: [.smite, .guardingBlow],
                ultimates: [.radiantCrash, .oathbreaker]
            )
        ),
        Combatant(
            id: "rogue",
            name: "Rogue",
            role: .hero,
            maxHealth: 8,
            abilityChoices: AbilityChoices(
                basics: [.quickCut, .strike],
                skills: [.smite, .guardingBlow],
                ultimates: [.oathbreaker, .radiantCrash]
            )
        ),
        Combatant(
            id: "mage",
            name: "Mage",
            role: .hero,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.ember, .strike],
                skills: [.firebolt, .kindle],
                ultimates: [.meteor, .inferno]
            )
        )
    ]

    static let pets = [
        Combatant(
            id: "wolf",
            name: "Wolf",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.strike, .quickCut],
                skills: [.smite, .guardingBlow],
                ultimates: [.radiantCrash, .oathbreaker]
            )
        ),
        Combatant(
            id: "hawk",
            name: "Hawk",
            role: .pet,
            maxHealth: 5,
            abilityChoices: AbilityChoices(
                basics: [.quickCut, .strike],
                skills: [.guardingBlow, .smite],
                ultimates: [.oathbreaker, .radiantCrash]
            )
        ),
        Combatant(
            id: "drake",
            name: "Drake",
            role: .pet,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.ember, .strike],
                skills: [.firebolt, .kindle],
                ultimates: [.meteor, .inferno]
            )
        )
    ]

    static let trainingSlime = Combatant(
        id: "training-slime",
        name: "Training Slime",
        role: .enemy,
        maxHealth: 35,
        abilityChoices: AbilityChoices(
            basics: [.strike, .shieldJab],
            skills: [.guardingBlow, .smite],
            ultimates: [.oathbreaker, .radiantCrash]
        )
    )
}

extension Combatant {
    static var heroes: [Combatant] { GameContent.heroes }
    static var pets: [Combatant] { GameContent.pets }
    static var trainingSlime: Combatant { GameContent.trainingSlime }
}

struct BattleDebugConfiguration: Equatable, Hashable {
    let isEnabled: Bool
    let hero: Combatant
    let pet: Combatant
    let startsPaused: Bool

    static var disabled: BattleDebugConfiguration {
        BattleDebugConfiguration(
            isEnabled: false,
            hero: defaultHero,
            pet: defaultPet,
            startsPaused: false
        )
    }

    static var current: BattleDebugConfiguration {
        #if DEBUG
        parse(arguments: ProcessInfo.processInfo.arguments)
        #else
        disabled
        #endif
    }

    static func parse(arguments: [String]) -> BattleDebugConfiguration {
        #if DEBUG
        guard value(after: "-battleDebugHarness", in: arguments)?.lowercased() == "enabled" else {
            return disabled
        }

        return BattleDebugConfiguration(
            isEnabled: true,
            hero: combatant(
                matching: value(after: "-battleDebugHero", in: arguments),
                in: GameContent.heroes,
                default: defaultHero
            ),
            pet: combatant(
                matching: value(after: "-battleDebugPet", in: arguments),
                in: GameContent.pets,
                default: defaultPet
            ),
            startsPaused: boolValue(after: "-battleDebugPaused", in: arguments) ?? true
        )
        #else
        disabled
        #endif
    }

    private static var defaultHero: Combatant {
        GameContent.heroes.first { $0.id == "mage" } ?? GameContent.heroes[0]
    }

    private static var defaultPet: Combatant {
        GameContent.pets.first { $0.id == "drake" } ?? GameContent.pets[0]
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard
            let flagIndex = arguments.firstIndex(of: flag),
            arguments.indices.contains(flagIndex + 1)
        else {
            return nil
        }

        return arguments[flagIndex + 1]
    }

    private static func boolValue(after flag: String, in arguments: [String]) -> Bool? {
        guard let rawValue = value(after: flag, in: arguments)?.lowercased() else {
            return nil
        }

        switch rawValue {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    private static func combatant(
        matching value: String?,
        in combatants: [Combatant],
        default defaultCombatant: Combatant
    ) -> Combatant {
        guard let value else {
            return defaultCombatant
        }

        let normalizedValue = normalized(value)
        return combatants.first {
            normalized($0.id) == normalizedValue || normalized($0.name) == normalizedValue
        } ?? defaultCombatant
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

struct BattleState {
    struct ActionEvent: Identifiable, Equatable {
        enum Kind: Equatable {
            case ability
            case status
        }

        let id: Int
        let kind: Kind
        let actorName: String
        let abilityName: String
        let targetID: String
        let targetName: String
        let amount: Int
        let keyword: Keyword

        var damage: Int {
            amount
        }

        var damageType: Keyword {
            keyword
        }

        var floatingText: String {
            switch kind {
            case .ability:
                return "\(actorName) \(abilityName) -\(amount)"
            case .status:
                return "\(abilityName) -\(amount)"
            }
        }
    }

    struct LogEntry: Identifiable, Equatable {
        let id: Int
        let text: String
    }

    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant

    private(set) var enemyHealth: Int
    private(set) var actionCount: Int
    private(set) var tickCount: Int
    private(set) var heroActionCount: Int
    private(set) var petActionCount: Int
    private(set) var log: [LogEntry]
    private(set) var activeEnemyStatuses: [ActiveStatus]

    private var nextEventID: Int
    private var nextStatusID: Int
    private var hasLoggedDefeat: Bool

    init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant = .trainingSlime,
        activeEnemyStatuses: [ActiveStatus] = []
    ) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
        enemyHealth = enemy.maxHealth
        actionCount = 0
        tickCount = 0
        heroActionCount = 0
        petActionCount = 0
        nextEventID = 0
        nextStatusID = activeEnemyStatuses.map(\.id).max() ?? 0
        hasLoggedDefeat = false
        self.activeEnemyStatuses = activeEnemyStatuses
        log = [
            LogEntry(id: 0, text: "\(hero.name) and \(pet.name) face \(enemy.name).")
        ]
    }

    var isEnemyDefeated: Bool {
        enemyHealth == 0
    }

    var nextActor: Combatant {
        actionCount.isMultiple(of: 2) ? hero : pet
    }

    var enemyStatusSummaries: [StatusSummary] {
        Keyword.allCases.compactMap { keyword in
            let stacks = activeEnemyStatuses.filter { $0.keyword == keyword }
            guard !stacks.isEmpty else { return nil }

            return StatusSummary(
                keyword: keyword,
                stackCount: stacks.count,
                totalTickDamage: stacks.reduce(0) { $0 + $1.tickDamage }
            )
        }
    }

    @discardableResult
    mutating func performNextAction() -> [ActionEvent] {
        guard !isEnemyDefeated else { return [] }

        tickCount += 1
        var events = applyEnemyStatusTicks()
        guard !isEnemyDefeated else {
            appendDefeatLogIfNeeded()
            return events
        }

        let actor = nextActor
        let actorTurnNumber = nextTurnNumber(for: actor)
        guard let ability = selectedAbility(for: actor, turnNumber: actorTurnNumber) else {
            return events
        }

        enemyHealth = max(0, enemyHealth - ability.directDamage)
        actionCount += 1
        incrementTurnCount(for: actor)

        let event = nextEvent(
            kind: .ability,
            actorName: actor.name,
            abilityName: ability.name,
            amount: ability.directDamage,
            keyword: ability.damageKeyword
        )
        events.append(event)

        var logText = "\(actor.name) uses \(ability.name) for \(ability.directDamage) \(ability.damageKeyword.rawValue) damage"
        if let statusApplication = ability.statusApplication, !isEnemyDefeated {
            appendEnemyStatus(statusApplication)
            logText += " and applies \(statusApplication.summary)"
        }
        log.append(LogEntry(id: event.id, text: "\(logText)."))

        appendDefeatLogIfNeeded()
        return events
    }

    private func nextTurnNumber(for actor: Combatant) -> Int {
        switch actor.role {
        case .hero:
            return heroActionCount + 1
        case .pet:
            return petActionCount + 1
        case .enemy:
            return 1
        }
    }

    private mutating func incrementTurnCount(for actor: Combatant) {
        switch actor.role {
        case .hero:
            heroActionCount += 1
        case .pet:
            petActionCount += 1
        case .enemy:
            break
        }
    }

    private func selectedAbility(for actor: Combatant, turnNumber: Int) -> Ability? {
        let tier = preferredTier(for: turnNumber)

        return actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first
    }

    private func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) {
            return .ultimate
        }

        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) {
            return .skill
        }

        return .basic
    }

    private mutating func applyEnemyStatusTicks() -> [ActionEvent] {
        var events: [ActionEvent] = []

        for keyword in Keyword.allCases {
            guard !isEnemyDefeated else { break }
            let stacks = activeEnemyStatuses.filter { $0.keyword == keyword }
            guard !stacks.isEmpty else { continue }

            let totalDamage = stacks.reduce(0) { $0 + $1.tickDamage }
            enemyHealth = max(0, enemyHealth - totalDamage)
            let event = nextEvent(
                kind: .status,
                actorName: keyword.rawValue,
                abilityName: keyword.rawValue,
                amount: totalDamage,
                keyword: keyword
            )
            events.append(event)
            log.append(LogEntry(
                id: event.id,
                text: "\(enemy.name) takes \(totalDamage) \(keyword.rawValue) damage."
            ))
        }

        activeEnemyStatuses = activeEnemyStatuses.compactMap { status in
            var updatedStatus = status
            updatedStatus.remainingTicks -= 1
            return updatedStatus.remainingTicks > 0 ? updatedStatus : nil
        }

        return events
    }

    private mutating func appendEnemyStatus(_ application: StatusApplication) {
        nextStatusID += 1
        let status = ActiveStatus(
            id: nextStatusID,
            keyword: application.keyword,
            remainingTicks: application.durationTicks,
            tickDamage: application.tickDamage
        )

        activeEnemyStatuses.append(status)
    }

    private mutating func nextEvent(
        kind: ActionEvent.Kind,
        actorName: String,
        abilityName: String,
        amount: Int,
        keyword: Keyword
    ) -> ActionEvent {
        nextEventID += 1
        return ActionEvent(
            id: nextEventID,
            kind: kind,
            actorName: actorName,
            abilityName: abilityName,
            targetID: enemy.id,
            targetName: enemy.name,
            amount: amount,
            keyword: keyword
        )
    }

    private mutating func appendDefeatLogIfNeeded() {
        guard isEnemyDefeated, !hasLoggedDefeat else { return }

        hasLoggedDefeat = true
        log.append(LogEntry(
            id: nextEventID + 1000,
            text: "\(enemy.name) is defeated."
        ))
    }
}

struct BattleSimulationOptions: Equatable {
    let maxTicks: Int
    let runCount: Int
    let seed: UInt64?
    let recordsEvents: Bool
    let recordsLog: Bool

    init(
        maxTicks: Int = 100,
        runCount: Int = 1,
        seed: UInt64? = nil,
        recordsEvents: Bool = true,
        recordsLog: Bool = true
    ) {
        self.maxTicks = maxTicks
        self.runCount = runCount
        self.seed = seed
        self.recordsEvents = recordsEvents
        self.recordsLog = recordsLog
    }

    var resolvedMaxTicks: Int {
        max(0, maxTicks)
    }

    var resolvedRunCount: Int {
        max(0, runCount)
    }
}

struct BattleMatchup: Equatable, Hashable {
    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant

    init(hero: Combatant, pet: Combatant, enemy: Combatant = .trainingSlime) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
    }
}

enum BattleSimulationOutcome: Equatable {
    case victory
    case tickLimit
}

struct BattleSimulationMetrics: Equatable {
    let totalDamage: Int
    let abilityDamage: Int
    let statusDamage: Int
    let actorDamage: [String: Int]
    let keywordDamage: [Keyword: Int]

    static func collect(from events: [BattleState.ActionEvent]) -> BattleSimulationMetrics {
        var accumulator = BattleSimulationMetricsAccumulator()
        accumulator.record(events)
        return accumulator.metrics
    }
}

private struct BattleSimulationMetricsAccumulator {
    private var abilityDamage = 0
    private var statusDamage = 0
    private var actorDamage: [String: Int] = [:]
    private var keywordDamage: [Keyword: Int] = [:]

    mutating func record(_ events: [BattleState.ActionEvent]) {
        for event in events {
            switch event.kind {
            case .ability:
                abilityDamage += event.amount
            case .status:
                statusDamage += event.amount
            }

            actorDamage[event.actorName, default: 0] += event.amount
            keywordDamage[event.keyword, default: 0] += event.amount
        }
    }

    var metrics: BattleSimulationMetrics {
        BattleSimulationMetrics(
            totalDamage: abilityDamage + statusDamage,
            abilityDamage: abilityDamage,
            statusDamage: statusDamage,
            actorDamage: actorDamage,
            keywordDamage: keywordDamage
        )
    }
}

struct BattleSimulationResult: Equatable {
    let matchup: BattleMatchup
    let outcome: BattleSimulationOutcome
    let tickCount: Int
    let actionCount: Int
    let finalEnemyHealth: Int
    let finalEnemyStatuses: [ActiveStatus]
    let finalEnemyStatusSummaries: [StatusSummary]
    let metrics: BattleSimulationMetrics
    let events: [BattleState.ActionEvent]
    let log: [BattleState.LogEntry]

    var didWin: Bool {
        outcome == .victory
    }

    var didHitTickLimit: Bool {
        outcome == .tickLimit
    }
}

struct BattleSimulationSummary: Equatable {
    let runCount: Int
    let winCount: Int
    let tickLimitCount: Int
    let winRate: Double
    let averageTickCount: Double
    let minimumTickCount: Int?
    let maximumTickCount: Int?
    let averageActionCount: Double
    let averageFinalEnemyHealth: Double
    let averageTotalDamage: Double
    let averageAbilityDamage: Double
    let averageStatusDamage: Double

    static func summarize(_ results: [BattleSimulationResult]) -> BattleSimulationSummary {
        let runCount = results.count
        let winCount = results.filter(\.didWin).count
        let tickLimitCount = results.filter(\.didHitTickLimit).count

        return BattleSimulationSummary(
            runCount: runCount,
            winCount: winCount,
            tickLimitCount: tickLimitCount,
            winRate: ratio(winCount, to: runCount),
            averageTickCount: average(results.map(\.tickCount)),
            minimumTickCount: results.map(\.tickCount).min(),
            maximumTickCount: results.map(\.tickCount).max(),
            averageActionCount: average(results.map(\.actionCount)),
            averageFinalEnemyHealth: average(results.map(\.finalEnemyHealth)),
            averageTotalDamage: average(results.map(\.metrics.totalDamage)),
            averageAbilityDamage: average(results.map(\.metrics.abilityDamage)),
            averageStatusDamage: average(results.map(\.metrics.statusDamage))
        )
    }

    private static func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func ratio(_ value: Int, to total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }
}

struct BattleBatchResult: Equatable {
    let matchup: BattleMatchup
    let options: BattleSimulationOptions
    let results: [BattleSimulationResult]
    let summary: BattleSimulationSummary
}

struct SeededRandomNumberGenerator: RandomNumberGenerator, Equatable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

enum BattleSimulator {
    static func run(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant = .trainingSlime,
        maxTicks: Int = 100
    ) -> BattleSimulationResult {
        run(
            BattleMatchup(hero: hero, pet: pet, enemy: enemy),
            options: BattleSimulationOptions(maxTicks: maxTicks)
        )
    }

    static func run(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant = .trainingSlime,
        options: BattleSimulationOptions
    ) -> BattleSimulationResult {
        run(
            BattleMatchup(hero: hero, pet: pet, enemy: enemy),
            options: options
        )
    }

    static func run(
        _ matchup: BattleMatchup,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        run(
            BattleState(hero: matchup.hero, pet: matchup.pet, enemy: matchup.enemy),
            options: options
        )
    }

    static func run(
        _ initialBattle: BattleState,
        maxTicks: Int = 100
    ) -> BattleSimulationResult {
        run(
            initialBattle,
            options: BattleSimulationOptions(maxTicks: maxTicks)
        )
    }

    static func run(
        _ initialBattle: BattleState,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        if let seed = options.seed {
            var rng = SeededRandomNumberGenerator(seed: seed)
            return run(initialBattle, options: options, rng: &rng)
        }

        var rng = SystemRandomNumberGenerator()
        return run(initialBattle, options: options, rng: &rng)
    }

    static func run<RNG: RandomNumberGenerator>(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant = .trainingSlime,
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> BattleSimulationResult {
        run(
            BattleMatchup(hero: hero, pet: pet, enemy: enemy),
            options: options,
            rng: &rng
        )
    }

    static func run<RNG: RandomNumberGenerator>(
        _ matchup: BattleMatchup,
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> BattleSimulationResult {
        run(
            BattleState(hero: matchup.hero, pet: matchup.pet, enemy: matchup.enemy),
            options: options,
            rng: &rng
        )
    }

    static func run<RNG: RandomNumberGenerator>(
        _ initialBattle: BattleState,
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> BattleSimulationResult {
        var battle = initialBattle
        var capturedEvents: [BattleState.ActionEvent] = []
        var metricsAccumulator = BattleSimulationMetricsAccumulator()
        let tickLimit = options.resolvedMaxTicks
        _ = rng

        while !battle.isEnemyDefeated, battle.tickCount < tickLimit {
            let tickEvents = battle.performNextAction()
            metricsAccumulator.record(tickEvents)
            if options.recordsEvents {
                capturedEvents.append(contentsOf: tickEvents)
            }
        }

        let capturedLog = options.recordsLog ? battle.log : []
        return BattleSimulationResult(
            matchup: BattleMatchup(hero: battle.hero, pet: battle.pet, enemy: battle.enemy),
            outcome: battle.isEnemyDefeated ? .victory : .tickLimit,
            tickCount: battle.tickCount,
            actionCount: battle.actionCount,
            finalEnemyHealth: battle.enemyHealth,
            finalEnemyStatuses: battle.activeEnemyStatuses,
            finalEnemyStatusSummaries: battle.enemyStatusSummaries,
            metrics: metricsAccumulator.metrics,
            events: capturedEvents,
            log: capturedLog
        )
    }

    static func runBatch(
        matchups: [BattleMatchup],
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> [BattleBatchResult] {
        if let seed = options.seed {
            var rng = SeededRandomNumberGenerator(seed: seed)
            return runBatch(matchups: matchups, options: options, rng: &rng)
        }

        var rng = SystemRandomNumberGenerator()
        return runBatch(matchups: matchups, options: options, rng: &rng)
    }

    static func runBatch<RNG: RandomNumberGenerator>(
        matchups: [BattleMatchup],
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> [BattleBatchResult] {
        matchups.map { matchup in
            let results = (0..<options.resolvedRunCount).map { _ in
                run(matchup, options: options, rng: &rng)
            }

            return BattleBatchResult(
                matchup: matchup,
                options: options,
                results: results,
                summary: BattleSimulationSummary.summarize(results)
            )
        }
    }
}
