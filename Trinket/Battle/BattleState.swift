import Foundation

struct BattleState {
    struct ActionEvent: Identifiable, Equatable {
        enum Kind: Equatable {
            case ability
            case status
            case effect
        }

        enum EffectKind: Equatable {
            case instantHeal
            case resourceGain
            case leechHeal
            case shieldApplied
            case mitigationApplied
            case shieldAbsorbed
            case preventionSkipped
            case preventionApplied
            case cleanseApplied
        }

        let id: Int
        let kind: Kind
        let effectKind: EffectKind?
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
                return "-\(amount)"
            case .status:
                return "-\(amount) \(keyword.rawValue)"
            case .effect:
                guard let effectKind else { return keyword.rawValue }
                switch effectKind {
                case .instantHeal: return "+\(amount) \(keyword.rawValue)"
                case .resourceGain: return "+\(amount) \(keyword.rawValue)"
                case .leechHeal: return "+\(amount) \(keyword.rawValue)"
                case .shieldApplied: return "+\(amount) \(keyword.rawValue)"
                case .mitigationApplied: return "+\(Int(Double(amount)))% \(keyword.rawValue)"
                case .shieldAbsorbed: return "-\(amount) \(keyword.rawValue)"
                case .preventionSkipped: return keyword.rawValue
                case .preventionApplied: return "+\(keyword.rawValue)"
                case .cleanseApplied: return "Cleanse \(keyword.rawValue)"
                }
            }
        }
    }

    struct LogEntry: Identifiable, Equatable {
        let id: Int
        let text: String
    }

    static let defaultHeroActionIntervalTicks: Int = 2
    static let defaultPetActionIntervalTicks: Int = 2
    static let defaultEnemyActionIntervalTicks: Int = 6

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
    private(set) var activeEnemyEffects: [ActiveEffect]
    private(set) var activeHeroEffects: [ActiveEffect]
    private(set) var activePetEffects: [ActiveEffect]
    private(set) var gold: Int

    private var heroActionSpeed: ActionSpeed
    private var petActionSpeed: ActionSpeed
    private var enemyActionSpeed: ActionSpeed

    private var nextEventID: Int
    private var nextEffectID: Int
    private var hasLoggedDefeat: Bool
    private var hasLoggedPartyDefeat: Bool
    private var heroNextReadyAtTick: Int
    private var petNextReadyAtTick: Int
    private var enemyNextReadyAtTick: Int
    private let initialGold: Int

    init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activePetEffects: [ActiveEffect] = [],
        initialGold: Int = 0
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

        self.activeEnemyEffects = activeEnemyEffects
        self.activeHeroEffects = activeHeroEffects
        self.activePetEffects = activePetEffects

        heroActionSpeed = ActionSpeed(baseIntervalTicks: hero.actionIntervalTicks ?? Self.defaultHeroActionIntervalTicks)
        petActionSpeed = ActionSpeed(baseIntervalTicks: pet.actionIntervalTicks ?? Self.defaultPetActionIntervalTicks)
        enemyActionSpeed = ActionSpeed(baseIntervalTicks: resolvedEnemy.actionIntervalTicks ?? Self.defaultEnemyActionIntervalTicks)

        nextEventID = 0
        nextEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activePetEffects.map(\.id).max() ?? 0
        )
        hasLoggedDefeat = false
        hasLoggedPartyDefeat = false

        heroNextReadyAtTick = heroActionSpeed.effectiveInterval
        petNextReadyAtTick = petActionSpeed.effectiveInterval
        enemyNextReadyAtTick = enemyActionSpeed.effectiveInterval

        self.initialGold = initialGold
        gold = initialGold

        log = [
            LogEntry(id: 0, text: "\(hero.name) and \(pet.name) face \(resolvedEnemy.name).")
        ]
    }

    var earnedGold: Int {
        gold - initialGold
    }

    var isEnemyDefeated: Bool {
        enemyHealth == 0
    }

    var isHeroAlive: Bool {
        heroHealth > 0
    }

    var isPetAlive: Bool {
        petHealth > 0
    }

    var isPartyDefeated: Bool {
        !isHeroAlive && !isPetAlive
    }

    var isBattleOver: Bool {
        isEnemyDefeated || isPartyDefeated
    }

    var enemyAttackTarget: Combatant {
        if !isHeroAlive { return pet }
        if !isPetAlive { return hero }
        return heroHealth >= petHealth ? hero : pet
    }

    var enemyEffectSummaries: [EffectSummary] {
        groupedEffectSummaries(for: activeEnemyEffects)
    }

    var heroEffectSummaries: [EffectSummary] {
        groupedEffectSummaries(for: activeHeroEffects)
    }

    var petEffectSummaries: [EffectSummary] {
        groupedEffectSummaries(for: activePetEffects)
    }

    private func groupedEffectSummaries(for effects: [ActiveEffect]) -> [EffectSummary] {
        Dictionary(grouping: effects, by: \.keyword).compactMap { keyword, group in
            let stacks = group.map(\.effect)
            guard !stacks.isEmpty else { return nil }

            let dotTotal = stacks.reduce(0) { sum, effect in
                if case let .damageOverTime(_, d, _) = effect { return sum + d }
                return sum
            }

            if dotTotal > 0 {
                return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(dotTotal) damage next tick, \(stacks.count) \(stacks.count == 1 ? "stack" : "stacks").")
            }

            let shieldTotal = stacks.reduce(0) { sum, effect in
                if case let .shield(_, b, _) = effect { return sum + b }
                return sum
            }
            if shieldTotal > 0 {
                let maxTicks = stacks.compactMap { eff -> Int? in
                    if case let .shield(_, _, d) = eff { return group.first(where: { $0.effect == eff })?.remainingTicks ?? d }
                    return nil
                }.min() ?? 0
                return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(shieldTotal) buffer, \(maxTicks) ticks left.")
            }

            let mitigationPct = stacks.reduce(0.0) { sum, effect in
                if case let .mitigation(_, p, _) = effect { return sum + p }
                return sum
            }
            if mitigationPct > 0 {
                let maxTicks = stacks.compactMap { eff -> Int? in
                    if case let .mitigation(_, _, d) = eff { return group.first(where: { $0.effect == eff })?.remainingTicks ?? d }
                    return nil
                }.min() ?? 0
                return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(Int(mitigationPct * 100))% mitigation, \(maxTicks) ticks left.")
            }

            if stacks.contains(where: { if case .prevention = $0 { return true }; return false }) {
                let maxActions = stacks.compactMap { eff -> Int? in
                    if case .prevention = eff {
                        return group.first(where: { $0.effect == eff })?.remainingTicks
                    }
                    return nil
                }.min() ?? 0
                return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(maxActions) actions prevented.")
            }

            let leechPct = stacks.reduce(0.0) { sum, effect in
                if case let .leech(_, p, _) = effect { return sum + p }
                return sum
            }
            if leechPct > 0 {
                let maxTicks = stacks.compactMap { eff -> Int? in
                    if case let .leech(_, _, d) = eff { return group.first(where: { $0.effect == eff })?.remainingTicks ?? d }
                    return nil
                }.min() ?? 0
                return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(Int(leechPct * 100))% leech, \(maxTicks) ticks left.")
            }

            if stacks.contains(where: { if case .cleanse = $0 { return true }; return false }) {
                let maxTicks = stacks.compactMap { eff -> Int? in
                    if case let .cleanse(_, d) = eff { return group.first(where: { $0.effect == eff })?.remainingTicks ?? d }
                    return nil
                }.min() ?? 0
                return EffectSummary(keyword: keyword, text: "Cleanse: \(maxTicks) ticks left.")
            }

            return nil
        }
    }

    private func effects(for combatant: Combatant) -> [ActiveEffect] {
        if combatant.id == hero.id { return activeHeroEffects }
        if combatant.id == pet.id { return activePetEffects }
        return activeEnemyEffects
    }

    private mutating func setEffects(_ newEffects: [ActiveEffect], for combatant: Combatant) {
        if combatant.id == hero.id { activeHeroEffects = newEffects }
        else if combatant.id == pet.id { activePetEffects = newEffects }
        else { activeEnemyEffects = newEffects }
    }

    @discardableResult
    mutating func performNextAction() -> [ActionEvent] {
        guard !isBattleOver else { return [] }

        tickCount += 1
        var events = applyAllEffectTicks()

        guard !isBattleOver else {
            appendDefeatLogIfNeeded()
            appendPartyDefeatLogIfNeeded()
            return events
        }

        for actor in readyCombatants() {
            guard !isBattleOver else { break }

            if actor.role == .enemy, isEnemyDefeated { break }

            let abilityTarget = actor.role == .enemy ? enemyAttackTarget : enemy
            if hasActivePrevention(actor: actor) {
                events.append(contentsOf: consumePrevention(for: actor))
            } else {
                events.append(contentsOf: performAction(actor: actor, abilityTarget: abilityTarget))
            }

            if isEnemyDefeated || isPartyDefeated { break }
        }

        appendDefeatLogIfNeeded()
        appendPartyDefeatLogIfNeeded()
        return events
    }

    private func readyCombatants() -> [Combatant] {
        var ready: [(combatant: Combatant, interval: Int, order: Int)] = []

        if heroNextReadyAtTick <= tickCount, isHeroAlive {
            ready.append((hero, heroActionSpeed.effectiveInterval, 0))
        }
        if petNextReadyAtTick <= tickCount, isPetAlive {
            ready.append((pet, petActionSpeed.effectiveInterval, 1))
        }
        if enemyNextReadyAtTick <= tickCount, !isEnemyDefeated {
            ready.append((enemy, enemyActionSpeed.effectiveInterval, 2))
        }

        return ready
            .sorted {
                if $0.interval != $1.interval { return $0.interval < $1.interval }
                return $0.order < $1.order
            }
            .map(\.combatant)
    }

    private func hasActivePrevention(actor: Combatant) -> Bool {
        effects(for: actor).contains(where: {
            if case .prevention = $0.effect, $0.remainingTicks > 0 { return true }
            return false
        })
    }

    private mutating func consumePrevention(for actor: Combatant) -> [ActionEvent] {
        var activeEffects = effects(for: actor)
        var events: [ActionEvent] = []

        if let index = activeEffects.firstIndex(where: {
            if case .prevention = $0.effect { return true }
            return false
        }) {
            let effect = activeEffects[index]
            let event = nextEvent(
                kind: .effect,
                effectKind: .preventionSkipped,
                actorName: effect.keyword.rawValue,
                abilityName: effect.keyword.rawValue,
                target: actor,
                amount: 0,
                keyword: effect.keyword
            )
            events.append(event)

            if effect.remainingTicks <= 1 {
                activeEffects.remove(at: index)
            } else {
                activeEffects[index].remainingTicks -= 1
            }
        }

        setEffects(activeEffects, for: actor)
        recordAction(for: actor)
        return events
    }

    private mutating func recordAction(for actor: Combatant) {
        actionCount += 1
        switch actor.role {
        case .hero: heroActionCount += 1
        case .pet: petActionCount += 1
        case .enemy: enemyActionCount += 1
        }
        advanceSchedule(for: actor)
    }

    private func actionSpeed(for actor: Combatant) -> ActionSpeed {
        switch actor.role {
        case .hero: return heroActionSpeed
        case .pet: return petActionSpeed
        case .enemy: return enemyActionSpeed
        }
    }

    private mutating func performAction(actor: Combatant, abilityTarget: Combatant) -> [ActionEvent] {
        let turnNumber: Int
        switch actor.role {
        case .hero: turnNumber = heroActionCount + 1
        case .pet: turnNumber = petActionCount + 1
        case .enemy: turnNumber = enemyActionCount + 1
        }

        guard let ability = selectedAbility(for: actor, turnNumber: turnNumber) else {
            recordAction(for: actor)
            return []
        }

        var events: [ActionEvent] = []

        let (dealt, damageShieldEvents) = applyDamage(ability.directDamage, to: abilityTarget)
        events.append(contentsOf: damageShieldEvents)

        let event = nextEvent(
            kind: .ability,
            effectKind: nil,
            actorName: actor.name,
            abilityName: ability.name,
            target: abilityTarget,
            amount: dealt,
            keyword: ability.damageKeyword
        )
        events.append(event)

        var logText = "\(actor.name) uses \(ability.name) for \(dealt) \(ability.damageKeyword.rawValue) damage to \(abilityTarget.name)"
        var appliedEffectLogs: [String] = []

        let effectsToApply: [TargetedEffect] = ability.targetedEffects.isEmpty
            ? (ability.statusApplication.map {
                [TargetedEffect(.damageOverTime($0.keyword, $0.tickDamage, $0.durationTicks), target: .abilityTarget)]
            } ?? [])
            : ability.targetedEffects

        for targetedEffect in effectsToApply {
            let effect = targetedEffect.effect
            let effectTarget = resolveEffectTarget(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget
            )

            switch effect {
            case let .damageOverTime(keyword, tickDamage, durationTicks):
                guard health(for: effectTarget) > 0 else { break }
                let ae = ActiveEffect(id: nextEffectID, effect: effect, remainingTicks: durationTicks)
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append("\(effect.summary)")

            case let .prevention(keyword, durationActions):
                guard health(for: effectTarget) > 0 else { break }
                let ae = ActiveEffect(id: nextEffectID, effect: effect, remainingTicks: durationActions)
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append("\(effect.summary)")
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .preventionApplied,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: 0,
                    keyword: keyword
                ))

            case let .shield(keyword, buffer, durationTicks):
                let ae = ActiveEffect(id: nextEffectID, effect: effect, remainingTicks: durationTicks)
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append("\(effect.summary)")
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .shieldApplied,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: buffer,
                    keyword: keyword
                ))

            case let .mitigation(keyword, percent, durationTicks):
                let ae = ActiveEffect(id: nextEffectID, effect: effect, remainingTicks: durationTicks)
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append("\(effect.summary)")
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .mitigationApplied,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: Int(percent * 100),
                    keyword: keyword
                ))

            case let .instantHeal(keyword, amount):
                applyHeal(amount, to: effectTarget)
                appliedEffectLogs.append("\(effect.summary)")
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .instantHeal,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: amount,
                    keyword: keyword
                ))

            case let .leech(keyword, percent, durationTicks):
                let ae = ActiveEffect(id: nextEffectID, effect: effect, remainingTicks: durationTicks)
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append("\(effect.summary)")

            case let .resourceGain(keyword, amount):
                gold += amount
                appliedEffectLogs.append("\(effect.summary)")
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: amount,
                    keyword: keyword
                ))

            case let .cleanse(targetKeyword, durationTicks):
                let ae = ActiveEffect(id: nextEffectID, effect: effect, remainingTicks: durationTicks)
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)

                if let removeKeyword = targetKeyword {
                    currentEffects.removeAll { $0.keyword == removeKeyword }
                } else {
                    currentEffects.removeAll()
                }
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(removeEffectsSummary(targetKeyword))
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .cleanseApplied,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: 0,
                    keyword: targetKeyword ?? .health
                ))
            }
        }

        if dealt > 0 {
            let activeLeech = effects(for: actor).filter {
                if case .leech = $0.effect { return true }
                return false
            }
            let leechPct = activeLeech.reduce(0.0) { sum, ae in
                if case let .leech(_, p, _) = ae.effect { return sum + p }
                return sum
            }
            if leechPct > 0 {
                let restored = Int(ceil(Double(dealt) * leechPct))
                if restored > 0 {
                    applyHeal(restored, to: actor)
                    events.append(nextEvent(
                        kind: .effect,
                        effectKind: .leechHeal,
                        actorName: actor.name,
                        abilityName: ability.name,
                        target: actor,
                        amount: restored,
                        keyword: .leech
                    ))
                }
            }
        }

        if !appliedEffectLogs.isEmpty {
            logText += " and applies " + appliedEffectLogs.joined(separator: ", ")
        }
        log.append(LogEntry(id: event.id, text: "\(logText)."))

        recordAction(for: actor)
        return events
    }

    private func resolveEffectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant
    ) -> Combatant {
        switch target {
        case .abilityTarget:
            return abilityTarget
        case .actor:
            return actor
        case .enemy:
            return enemy
        case .hero:
            return hero
        case .pet:
            return pet
        }
    }

    private func removeEffectsSummary(_ keyword: Keyword?) -> String {
        if let keyword { return "Remove \(keyword.rawValue)" }
        return "Remove all effects"
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

    private mutating func applyAllEffectTicks() -> [ActionEvent] {
        var events: [ActionEvent] = []

        let enemyResult = tickEffects(activeEnemyEffects, target: enemy)
        activeEnemyEffects = enemyResult.updated
        events.append(contentsOf: enemyResult.events)

        if isHeroAlive {
            let heroResult = tickEffects(activeHeroEffects, target: hero)
            activeHeroEffects = heroResult.updated
            events.append(contentsOf: heroResult.events)
        }

        if isPetAlive {
            let petResult = tickEffects(activePetEffects, target: pet)
            activePetEffects = petResult.updated
            events.append(contentsOf: petResult.events)
        }

        return events
    }

    private mutating func tickEffects(_ effects: [ActiveEffect], target: Combatant) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        var remaining = effects

        for ae in remaining {
            switch ae.effect {
            case let .damageOverTime(keyword, tickDamage, _):
                let (actualDamage, shieldEvents) = applyDamage(tickDamage, to: target)
                events.append(contentsOf: shieldEvents)
                let event = nextEvent(
                    kind: .status,
                    effectKind: nil,
                    actorName: keyword.rawValue,
                    abilityName: keyword.rawValue,
                    target: target,
                    amount: actualDamage,
                    keyword: keyword
                )
                events.append(event)
                log.append(LogEntry(
                    id: event.id,
                    text: "\(target.name) takes \(actualDamage) \(keyword.rawValue) damage."
                ))

            case let .cleanse(cleanseKeyword, _):
                if let removeKeyword = cleanseKeyword {
                    remaining.removeAll { $0.keyword == removeKeyword }
                } else {
                    remaining.removeAll { isEffectType($0.effect) }
                }
                remaining.append(ae)

            default:
                break
            }
        }

        remaining = remaining.compactMap { ae in
            if case .prevention = ae.effect {
                return ae
            }
            var updated = ae
            updated.remainingTicks -= 1
            return updated.remainingTicks > 0 ? updated : nil
        }

        return (events, remaining)
    }

    private func isEffectType(_ effect: Effect) -> Bool {
        switch effect {
        case .damageOverTime, .prevention, .shield, .mitigation, .leech, .cleanse: return true
        case .instantHeal, .resourceGain: return false
        }
    }

    private mutating func applyDamage(_ amount: Int, to combatant: Combatant) -> (healthLost: Int, shieldEvents: [ActionEvent]) {
        var remaining = amount
        var shieldEvents: [ActionEvent] = []

        var currentEffects = effects(for: combatant)
        var shieldIndexes: [Int] = []

        for (index, ae) in currentEffects.enumerated() {
            if case let .shield(keyword, buffer, _) = ae.effect {
                let absorbed = min(remaining, buffer)
                remaining -= absorbed
                if absorbed > 0 {
                    shieldEvents.append(nextEvent(
                        kind: .effect,
                        effectKind: .shieldAbsorbed,
                        actorName: keyword.rawValue,
                        abilityName: keyword.rawValue,
                        target: combatant,
                        amount: absorbed,
                        keyword: keyword
                    ))

                    let newBuffer = buffer - absorbed
                    let newEffect: Effect = .shield(keyword, newBuffer, ae.effect.durationTicks)
                    currentEffects[index] = ActiveEffect(id: ae.id, effect: newEffect, remainingTicks: ae.remainingTicks)
                    if newBuffer <= 0 {
                        shieldIndexes.append(index)
                    }
                }
            }
        }

        for index in shieldIndexes.reversed() {
            currentEffects.remove(at: index)
        }

        let mitigationPct = currentEffects.reduce(0.0) { sum, ae in
            if case let .mitigation(_, p, _) = ae.effect { return sum + p }
            return sum
        }
        if mitigationPct > 0 {
            remaining = Int(ceil(Double(remaining) * max(0, 1 - mitigationPct)))
        }

        setEffects(currentEffects, for: combatant)

        if combatant.id == hero.id {
            heroHealth = max(0, heroHealth - remaining)
        } else if combatant.id == pet.id {
            petHealth = max(0, petHealth - remaining)
        } else {
            enemyHealth = max(0, enemyHealth - remaining)
        }

        return (remaining, shieldEvents)
    }

    private mutating func applyHeal(_ amount: Int, to combatant: Combatant) {
        if combatant.id == hero.id {
            heroHealth = min(hero.maxHealth, heroHealth + amount)
        } else if combatant.id == pet.id {
            petHealth = min(pet.maxHealth, petHealth + amount)
        }
    }

    private func health(for combatant: Combatant) -> Int {
        if combatant.id == hero.id { return heroHealth }
        if combatant.id == pet.id { return petHealth }
        return enemyHealth
    }

    private mutating func advanceSchedule(for actor: Combatant) {
        let interval = actionSpeed(for: actor).effectiveInterval
        switch actor.role {
        case .hero: heroNextReadyAtTick = tickCount + interval
        case .pet: petNextReadyAtTick = tickCount + interval
        case .enemy: enemyNextReadyAtTick = tickCount + interval
        }
    }

    private mutating func nextEvent(
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind?,
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
            effectKind: effectKind,
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
