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

        var damage: Int { amount }

        var damageType: Keyword { keyword }

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

    static let defaultHeroAttackIntervalTicks: Int = 1
    static let defaultPetAttackIntervalTicks: Int = 1
    static let defaultEnemyAttackIntervalTicks: Int = 3

    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant

    private(set) var heroHealth: Int
    private(set) var petHealth: Int
    private(set) var enemyHealth: Int

    private(set) var tickCount: Int
    private(set) var actionCount: Int
    private(set) var heroActionCount: Int
    private(set) var petActionCount: Int
    private(set) var enemyActionCount: Int

    private(set) var log: [LogEntry]
    private(set) var activeEnemyStatuses: [ActiveStatus]
    private(set) var activeHeroStatuses: [ActiveStatus]
    private(set) var activePetStatuses: [ActiveStatus]

    private var nextEventID: Int
    private var nextStatusID: Int
    private var hasLoggedDefeat: Bool
    private var hasLoggedPartyDefeat: Bool
    private var heroNextReadyAtTick: Int
    private var petNextReadyAtTick: Int
    private var enemyNextReadyAtTick: Int

    init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        activeEnemyStatuses: [ActiveStatus] = [],
        activeHeroStatuses: [ActiveStatus] = [],
        activePetStatuses: [ActiveStatus] = []
    ) {
        self.hero = hero
        self.pet = pet
        let resolvedEnemy = enemy ?? Enemy.randomNormalCombatant
        self.enemy = resolvedEnemy

        heroHealth = hero.maxHealth
        petHealth = pet.maxHealth
        enemyHealth = resolvedEnemy.maxHealth

        tickCount = 0
        actionCount = 0
        heroActionCount = 0
        petActionCount = 0
        enemyActionCount = 0

        self.activeEnemyStatuses = activeEnemyStatuses
        self.activeHeroStatuses = activeHeroStatuses
        self.activePetStatuses = activePetStatuses

        nextEventID = 0
        nextStatusID = max(
            activeEnemyStatuses.map(\.id).max() ?? 0,
            activeHeroStatuses.map(\.id).max() ?? 0,
            activePetStatuses.map(\.id).max() ?? 0
        )
        hasLoggedDefeat = false
        hasLoggedPartyDefeat = false

        heroNextReadyAtTick = 1
        petNextReadyAtTick = 1
        enemyNextReadyAtTick = Self.defaultEnemyAttackIntervalTicks

        log = [
            LogEntry(id: 0, text: "\(hero.name) and \(pet.name) face \(resolvedEnemy.name).")
        ]
    }

    var isEnemyDefeated: Bool { enemyHealth == 0 }
    var isHeroAlive: Bool { heroHealth > 0 }
    var isPetAlive: Bool { petHealth > 0 }
    var isPartyDefeated: Bool { !isHeroAlive && !isPetAlive }
    var isBattleOver: Bool { isEnemyDefeated || isPartyDefeated }

    var enemyAttackTarget: Combatant {
        if !isHeroAlive { return pet }
        if !isPetAlive { return hero }
        return heroHealth >= petHealth ? hero : pet
    }

    var enemyStatusSummaries: [StatusSummary] { statusSummaries(for: activeEnemyStatuses) }
    var heroStatusSummaries: [StatusSummary] { statusSummaries(for: activeHeroStatuses) }
    var petStatusSummaries: [StatusSummary] { statusSummaries(for: activePetStatuses) }

    private func statusSummaries(for statuses: [ActiveStatus]) -> [StatusSummary] {
        Keyword.allCases.compactMap { keyword in
            let stacks = statuses.filter { $0.keyword == keyword }
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
        guard !isBattleOver else { return [] }

        tickCount += 1
        var events = applyStatusTicks()

        guard !isBattleOver else {
            appendDefeatLogIfNeeded()
            appendPartyDefeatLogIfNeeded()
            return events
        }

        if heroNextReadyAtTick <= tickCount, isHeroAlive {
            events.append(contentsOf: performAction(actor: hero, target: enemy))
        }

        if petNextReadyAtTick <= tickCount, isPetAlive {
            events.append(contentsOf: performAction(actor: pet, target: enemy))
        }

        if enemyNextReadyAtTick <= tickCount, !isEnemyDefeated {
            events.append(contentsOf: performAction(actor: enemy, target: enemyAttackTarget))
        }

        appendDefeatLogIfNeeded()
        appendPartyDefeatLogIfNeeded()
        return events
    }

    private mutating func performAction(actor: Combatant, target: Combatant) -> [ActionEvent] {
        let turnNumber: Int
        let interval: Int
        switch actor.role {
        case .hero:
            turnNumber = heroActionCount + 1
            interval = Self.defaultHeroAttackIntervalTicks
        case .pet:
            turnNumber = petActionCount + 1
            interval = Self.defaultPetAttackIntervalTicks
        case .enemy:
            turnNumber = enemyActionCount + 1
            interval = Self.defaultEnemyAttackIntervalTicks
        }

        guard let ability = selectedAbility(for: actor, turnNumber: turnNumber) else {
            advanceSchedule(actor: actor, interval: interval)
            return []
        }

        applyDamage(ability.directDamage, to: target)

        let event = nextEvent(
            kind: .ability,
            actorName: actor.name,
            abilityName: ability.name,
            target: target,
            amount: ability.directDamage,
            keyword: ability.damageKeyword
        )

        var logText = "\(actor.name) uses \(ability.name) for \(ability.directDamage) \(ability.damageKeyword.rawValue) damage to \(target.name)"

        if let statusApplication = ability.statusApplication, health(for: target) > 0 {
            if target.id == hero.id { activeHeroStatuses = applyStatus(statusApplication, to: activeHeroStatuses) }
            else if target.id == pet.id { activePetStatuses = applyStatus(statusApplication, to: activePetStatuses) }
            else { activeEnemyStatuses = applyStatus(statusApplication, to: activeEnemyStatuses) }
            logText += " and applies \(statusApplication.summary)"
        }

        log.append(LogEntry(id: event.id, text: "\(logText)."))

        actionCount += 1
        switch actor.role {
        case .hero: heroActionCount += 1
        case .pet: petActionCount += 1
        case .enemy: enemyActionCount += 1
        }
        advanceSchedule(actor: actor, interval: interval)

        return [event]
    }

    private func selectedAbility(for actor: Combatant, turnNumber: Int) -> Ability? {
        let tier = preferredTier(for: turnNumber)
        return actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first
    }

    private func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) { return .ultimate }
        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) { return .skill }
        return .basic
    }

    private mutating func applyStatusTicks() -> [ActionEvent] {
        var events: [ActionEvent] = []

        let enemyResult = tickStatuses(activeEnemyStatuses, target: enemy)
        activeEnemyStatuses = enemyResult.updated
        events.append(contentsOf: enemyResult.events)

        if isHeroAlive {
            let heroResult = tickStatuses(activeHeroStatuses, target: hero)
            activeHeroStatuses = heroResult.updated
            events.append(contentsOf: heroResult.events)
        }

        if isPetAlive {
            let petResult = tickStatuses(activePetStatuses, target: pet)
            activePetStatuses = petResult.updated
            events.append(contentsOf: petResult.events)
        }

        return events
    }

    private mutating func tickStatuses(_ statuses: [ActiveStatus], target: Combatant) -> (events: [ActionEvent], updated: [ActiveStatus]) {
        var events: [ActionEvent] = []
        var remaining = statuses

        for keyword in Keyword.allCases {
            let stacks = remaining.filter { $0.keyword == keyword }
            guard !stacks.isEmpty else { continue }

            let totalDamage = stacks.reduce(0) { $0 + $1.tickDamage }
            applyDamage(totalDamage, to: target)

            let event = nextEvent(
                kind: .status,
                actorName: keyword.rawValue,
                abilityName: keyword.rawValue,
                target: target,
                amount: totalDamage,
                keyword: keyword
            )
            events.append(event)
            log.append(LogEntry(
                id: event.id,
                text: "\(target.name) takes \(totalDamage) \(keyword.rawValue) damage."
            ))
        }

        remaining = remaining.compactMap { status in
            var updated = status
            updated.remainingTicks -= 1
            return updated.remainingTicks > 0 ? updated : nil
        }

        return (events, remaining)
    }

    private mutating func applyStatus(_ application: StatusApplication, to statuses: [ActiveStatus]) -> [ActiveStatus] {
        nextStatusID += 1
        var updated = statuses
        updated.append(ActiveStatus(
            id: nextStatusID,
            keyword: application.keyword,
            remainingTicks: application.durationTicks,
            tickDamage: application.tickDamage
        ))
        return updated
    }

    private mutating func applyDamage(_ amount: Int, to combatant: Combatant) {
        if combatant.id == hero.id {
            heroHealth = max(0, heroHealth - amount)
        } else if combatant.id == pet.id {
            petHealth = max(0, petHealth - amount)
        } else {
            enemyHealth = max(0, enemyHealth - amount)
        }
    }

    private func health(for combatant: Combatant) -> Int {
        if combatant.id == hero.id { return heroHealth }
        if combatant.id == pet.id { return petHealth }
        return enemyHealth
    }

    private mutating func advanceSchedule(actor: Combatant, interval: Int) {
        switch actor.role {
        case .hero: heroNextReadyAtTick = tickCount + interval
        case .pet: petNextReadyAtTick = tickCount + interval
        case .enemy: enemyNextReadyAtTick = tickCount + interval
        }
    }

    private mutating func nextEvent(
        kind: ActionEvent.Kind,
        actorName: String,
        abilityName: String,
        target: Combatant,
        amount: Int,
        keyword: Keyword
    ) -> ActionEvent {
        nextEventID += 1
        return ActionEvent(
            id: nextEventID,
            kind: kind,
            actorName: actorName,
            abilityName: abilityName,
            targetID: target.id,
            targetName: target.name,
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

    private mutating func appendPartyDefeatLogIfNeeded() {
        guard isPartyDefeated, !hasLoggedPartyDefeat else { return }

        hasLoggedPartyDefeat = true
        log.append(LogEntry(
            id: nextEventID + 2000,
            text: "Your party has been defeated by \(enemy.name)."
        ))
    }
}
