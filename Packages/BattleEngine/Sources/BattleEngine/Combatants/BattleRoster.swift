import TrinketContent
import TrinketCore

public enum BattleParticipant: CaseIterable, Sendable {
    case hero
    case companion
    case enemy

    public static let party: [Self] = [.hero, .companion]
    public static let effectTurnOrder: [Self] = [.enemy, .hero, .companion]

    public var isPartyMember: Bool {
        switch self {
        case .hero, .companion: true
        case .enemy: false
        }
    }
}

public struct BattleRoster {
    public package(set) var hero: CombatantRuntime
    public package(set) var companion: CombatantRuntime
    public package(set) var enemy: CombatantRuntime

    public init(hero: CombatantRuntime, companion: CombatantRuntime, enemy: CombatantRuntime) {
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
    }

    public package(set) subscript(participant: BattleParticipant) -> CombatantRuntime {
        get {
            switch participant {
            case .hero: hero
            case .companion: companion
            case .enemy: enemy
            }
        }
        set {
            switch participant {
            case .hero: hero = newValue
            case .companion: companion = newValue
            case .enemy: enemy = newValue
            }
        }
        _modify {
            // Borrow the stored runtime so mutation does not force a copy of its COW state.
            switch participant {
            case .hero: yield &hero
            case .companion: yield &companion
            case .enemy: yield &enemy
            }
        }
    }

    /// A role describes content; only a matching roster identity grants access to live state.
    public func participant(for combatant: Combatant) -> BattleParticipant? {
        guard let participant = participant(for: combatant.id),
              self[participant].combatant.role == combatant.role else { return nil }
        return participant
    }

    package func participant(for id: String) -> BattleParticipant? {
        if hero.id == id {
            return .hero
        }
        if companion.id == id {
            return .companion
        }
        if enemy.id == id {
            return .enemy
        }
        return nil
    }

    public func runtime(for combatant: Combatant) -> CombatantRuntime? {
        participant(for: combatant).map { self[$0] }
    }

    public func combatant(for id: String) -> CombatantRuntime? {
        participant(for: id).map { self[$0] }
    }

    package mutating func update(_ runtime: CombatantRuntime) {
        guard let participant = participant(for: runtime.combatant) else { return }
        self[participant] = runtime
    }

    public func activeEffects(for combatant: Combatant) -> [ActiveEffect] {
        runtime(for: combatant)?.activeEffects ?? []
    }

    package mutating func setActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        mutateRuntime(for: combatant) { runtime in
            runtime.activeEffects = effects
        }
    }

    public func health(for combatant: Combatant) -> Int {
        participant(for: combatant).map { self[$0].currentHealth } ?? 0
    }

    public func maxHealth(for combatant: Combatant) -> Int {
        participant(for: combatant).map { self[$0].maxHealth } ?? 0
    }

    func isBelowHalfHealth(for combatant: Combatant) -> Bool {
        participant(for: combatant).map { self[$0].isBelowHalfHealth } ?? false
    }

    func isAboveHalfHealth(for combatant: Combatant) -> Bool {
        participant(for: combatant).map { self[$0].isAboveHalfHealth } ?? false
    }

    public func maxMana(for combatant: Combatant) -> Int {
        participant(for: combatant).map { self[$0].maxMana } ?? 0
    }

    public var enemyAttackTarget: Combatant {
        if hero.isAlive, companion.isAlive {
            return hero.currentHealth >= companion.currentHealth ? hero.combatant : companion.combatant
        }
        if hero.isAlive {
            return hero.combatant
        }
        if companion.isAlive {
            return companion.combatant
        }
        return hero.combatant
    }

    public var isPartyDefeated: Bool {
        !hero.isAlive && !companion.isAlive
    }

    public var isEnemyDefeated: Bool {
        enemy.currentHealth == 0
    }

    func hasPendingActionSkip(for participant: BattleParticipant) -> Bool {
        self[participant].activeEffects.contains(where: \.isAwaitingActionSkip)
    }

    func hasPendingActionSkip(for participant: BattleParticipant, keyword: Keyword) -> Bool {
        self[participant].activeEffects.contains { $0.keyword == keyword && $0.isAwaitingActionSkip }
    }

    func hasControlStatus(for participant: BattleParticipant, keyword: Keyword) -> Bool {
        self[participant].activeEffects.contains { $0.keyword == keyword && $0.effect.isActionSkipPending }
    }

    func hasControlStatus(for participant: BattleParticipant) -> Bool {
        self[participant].activeEffects.contains(where: \.effect.isActionSkipPending)
    }

    func hasAffliction(_ keyword: Keyword, on participant: BattleParticipant) -> Bool {
        self[participant].activeEffects.contains { $0.effect.keyword == keyword && $0.isActiveAffliction }
    }

    package mutating func clearControlStatusLinger(for participant: BattleParticipant) {
        self[participant].activeEffects.removeAll { activeEffect in
            activeEffect.effect.isActionSkipPending && !activeEffect.isAwaitingActionSkip
        }
    }

    func isDeathsDoorActive(for participant: BattleParticipant) -> Bool {
        self[participant].activeEffects.contains { $0.effect.kind == .deathsDoor }
    }

    public func hasPendingActionSkip(for combatant: Combatant) -> Bool {
        participant(for: combatant).map { hasPendingActionSkip(for: $0) } ?? false
    }

    public func hasPendingActionSkip(for combatant: Combatant, keyword: Keyword) -> Bool {
        participant(for: combatant).map { hasPendingActionSkip(for: $0, keyword: keyword) } ?? false
    }

    public func hasControlStatus(for combatant: Combatant, keyword: Keyword) -> Bool {
        participant(for: combatant).map { hasControlStatus(for: $0, keyword: keyword) } ?? false
    }

    func hasAffliction(_ keyword: Keyword, on combatant: Combatant) -> Bool {
        participant(for: combatant).map { hasAffliction(keyword, on: $0) } ?? false
    }

    public func hasControlStatus(for combatant: Combatant) -> Bool {
        participant(for: combatant).map { hasControlStatus(for: $0) } ?? false
    }

    package mutating func clearControlStatusLinger(for combatant: Combatant) {
        guard let participant = participant(for: combatant) else { return }
        clearControlStatusLinger(for: participant)
    }

    package mutating func mutateRuntime(for combatant: Combatant, _ body: (inout CombatantRuntime) -> Void) {
        guard let participant = participant(for: combatant) else { return }
        body(&self[participant])
    }

    mutating func mutateEffects(for combatant: Combatant, _ body: (inout [ActiveEffect]) -> Void) {
        mutateRuntime(for: combatant) { body(&$0.activeEffects) }
    }

    mutating func mutateRuntime(forID id: String, _ body: (inout CombatantRuntime) -> Void) {
        guard let participant = participant(for: id) else { return }
        body(&self[participant])
    }

    public func hasConsumedDeathsDoor(for combatant: Combatant) -> Bool {
        participant(for: combatant).map { self[$0].hasConsumedDeathsDoor } ?? false
    }

    public func isDeathsDoorActive(for combatant: Combatant) -> Bool {
        participant(for: combatant).map { isDeathsDoorActive(for: $0) } ?? false
    }
}

/// Share affliction eligibility between live queries and hit-time snapshots.
extension ActiveEffect {
    var isActiveAffliction: Bool {
        switch effect {
        case let .bleed(potency): potency > 0 && remainingTurns > 0
        case let .burn(potency), let .poison(potency): potency > 0
        default: effect.isRemovableDebuff
        }
    }
}
