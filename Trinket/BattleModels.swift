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
    let directDamage: Int
    let damageKeyword: Keyword
    let statusApplication: StatusApplication?

    static let strike = Ability(
        id: "strike",
        name: "Strike",
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: nil
    )

    static let ember = Ability(
        id: "ember",
        name: "Ember",
        directDamage: 1,
        damageKeyword: .physical,
        statusApplication: StatusApplication(keyword: .burn, durationTicks: 2, tickDamage: 1)
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
    let abilities: [Ability]
}

enum GameContent {
    static let heroes = [
        Combatant(id: "paladin", name: "Paladin", role: .hero, maxHealth: 10, abilities: [.strike]),
        Combatant(id: "rogue", name: "Rogue", role: .hero, maxHealth: 8, abilities: [.strike]),
        Combatant(id: "mage", name: "Mage", role: .hero, maxHealth: 7, abilities: [.ember])
    ]

    static let pets = [
        Combatant(id: "wolf", name: "Wolf", role: .pet, maxHealth: 6, abilities: [.strike]),
        Combatant(id: "hawk", name: "Hawk", role: .pet, maxHealth: 5, abilities: [.strike]),
        Combatant(id: "drake", name: "Drake", role: .pet, maxHealth: 7, abilities: [.ember])
    ]

    static let trainingSlime = Combatant(
        id: "training-slime",
        name: "Training Slime",
        role: .enemy,
        maxHealth: 10,
        abilities: []
    )
}

extension Combatant {
    static var heroes: [Combatant] { GameContent.heroes }
    static var pets: [Combatant] { GameContent.pets }
    static var trainingSlime: Combatant { GameContent.trainingSlime }
}

struct BattleDebugConfiguration: Equatable {
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

        guard let ability = nextActor.abilities.first else { return events }
        let actor = nextActor
        enemyHealth = max(0, enemyHealth - ability.directDamage)
        actionCount += 1

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
