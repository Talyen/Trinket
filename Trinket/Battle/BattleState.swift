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
