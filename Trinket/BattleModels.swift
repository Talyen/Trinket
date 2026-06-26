import Foundation

enum GameMode: String, CaseIterable, Identifiable {
    case battle = "Battle"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .battle:
            return "Choose a Hero and Pet, then watch them test their Strike against an enemy."
        }
    }
}

enum DamageType: String {
    case physical = "Physical"
}

struct Ability: Identifiable, Hashable {
    let id: String
    let name: String
    let damage: Int
    let damageType: DamageType

    static let strike = Ability(
        id: "strike",
        name: "Strike",
        damage: 1,
        damageType: .physical
    )

    var summary: String {
        "\(damage) \(damageType.rawValue) damage"
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

    static let heroes = [
        Combatant(id: "paladin", name: "Paladin", role: .hero, maxHealth: 10, abilities: [.strike]),
        Combatant(id: "rogue", name: "Rogue", role: .hero, maxHealth: 8, abilities: [.strike]),
        Combatant(id: "mage", name: "Mage", role: .hero, maxHealth: 7, abilities: [.strike])
    ]

    static let pets = [
        Combatant(id: "wolf", name: "Wolf", role: .pet, maxHealth: 6, abilities: [.strike]),
        Combatant(id: "hawk", name: "Hawk", role: .pet, maxHealth: 5, abilities: [.strike]),
        Combatant(id: "drake", name: "Drake", role: .pet, maxHealth: 7, abilities: [.strike])
    ]

    static let trainingSlime = Combatant(
        id: "training-slime",
        name: "Training Slime",
        role: .enemy,
        maxHealth: 6,
        abilities: []
    )
}

struct BattleState {
    struct ActionEvent: Identifiable, Equatable {
        let id: Int
        let actorName: String
        let abilityName: String
        let targetID: String
        let targetName: String
        let amount: Int
        let damageType: DamageType

        var damage: Int {
            amount
        }

        var floatingText: String {
            "\(actorName) \(abilityName) -\(amount)"
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
    private(set) var log: [LogEntry]

    init(hero: Combatant, pet: Combatant, enemy: Combatant = .trainingSlime) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
        enemyHealth = enemy.maxHealth
        actionCount = 0
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

    @discardableResult
    mutating func performNextAction() -> ActionEvent? {
        guard !isEnemyDefeated else { return nil }
        guard let ability = nextActor.abilities.first else { return nil }

        let actor = nextActor
        let damage = ability.damage
        enemyHealth = max(0, enemyHealth - damage)
        actionCount += 1
        let event = ActionEvent(
            id: actionCount,
            actorName: actor.name,
            abilityName: ability.name,
            targetID: enemy.id,
            targetName: enemy.name,
            amount: damage,
            damageType: ability.damageType
        )

        log.append(LogEntry(
            id: actionCount,
            text: "\(actor.name) uses \(ability.name) for \(damage) \(ability.damageType.rawValue) damage."
        ))

        if isEnemyDefeated {
            log.append(LogEntry(
                id: actionCount + 1000,
                text: "\(enemy.name) is defeated."
            ))
        }

        return event
    }
}
