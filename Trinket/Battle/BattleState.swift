import Foundation

struct BattleState {
    private struct PairedDamageHit: Hashable {
        let keyword: Keyword
        let amount: Int
    }

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
            case preventionTriggered
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
            case .preventionTriggered: return "\(keyword.statusAlias ?? keyword.rawValue)!"
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

            if stacks.contains(where: \.isDecayingDoT) {
                return EffectSummary(keyword: keyword, text: "\(keyword.rawValue) active")
            }

            let bleedTotal = group.reduce(0) { sum, activeEffect in
                guard case let .bleed(potency) = activeEffect.effect, activeEffect.remainingTicks > 0 else {
                    return sum
                }
                return sum + potency
            }
            if bleedTotal > 0 {
                return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(bleedTotal) damage")
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

            if stacks.contains(where: { if case .preventionBuildup = $0 { return true }; return false }) {
                let amount = stacks.compactMap { eff -> Int? in
                    if case let .preventionBuildup(_, amt, _) = eff { return amt }
                    return nil
                }.reduce(0, +)
                let threshold = stacks.compactMap { eff -> Int? in
                    if case let .preventionBuildup(_, _, th) = eff { return th }
                    return nil
                }.max() ?? 1
                return EffectSummary(
                    keyword: keyword,
                    text: "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
                )
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
    mutating func advanceOneStep() -> BattleStep {
        guard !isBattleOver else { return .ended(events: []) }

        tickCount += 1
        var events = applyAllEffectTicks()

        if isBattleOver {
            appendDefeatLogIfNeeded()
            appendPartyDefeatLogIfNeeded()
            return .ended(events: events)
        }

        guard let actor = readyCombatants().first else {
            return .effectsOnly(events: events)
        }

        if actor.role == .enemy, isEnemyDefeated {
            return .effectsOnly(events: events)
        }

        let abilityTarget = actor.role == .enemy ? enemyAttackTarget : enemy
        if hasActivePrevention(actor: actor) {
            events.append(contentsOf: consumePrevention(for: actor))
        } else {
            events.append(contentsOf: performAction(actor: actor, abilityTarget: abilityTarget))
        }

        appendDefeatLogIfNeeded()
        appendPartyDefeatLogIfNeeded()

        if isBattleOver {
            return .ended(events: events)
        }

        return .acted(actor, events: events)
    }

    private func readyCombatants() -> [Combatant] {
        var ready: [(combatant: Combatant, interval: Int, order: Int, readyAtTick: Int)] = []

        if heroNextReadyAtTick <= tickCount, isHeroAlive {
            ready.append((hero, heroActionSpeed.effectiveInterval, 0, heroNextReadyAtTick))
        }
        if petNextReadyAtTick <= tickCount, isPetAlive {
            ready.append((pet, petActionSpeed.effectiveInterval, 1, petNextReadyAtTick))
        }
        if enemyNextReadyAtTick <= tickCount, !isEnemyDefeated {
            ready.append((enemy, enemyActionSpeed.effectiveInterval, 2, enemyNextReadyAtTick))
        }

        return ready
            .sorted {
                if $0.readyAtTick != $1.readyAtTick { return $0.readyAtTick < $1.readyAtTick }
                if $0.interval != $1.interval { return $0.interval > $1.interval }
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

        let (dealt, damageShieldEvents) = applyDamage(
            ability.directDamage,
            to: abilityTarget,
            damageKeyword: ability.damageKeyword,
            sourceActorID: actor.id
        )
        events.append(contentsOf: damageShieldEvents)
        if dealt > 0 {
            events.append(contentsOf: applyLeechFromDamage(dealt, sourceActorID: actor.id))
        }

        if ability.directDamage > 0 {
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
        }

        var logText: String
        if ability.directDamage > 0 {
            logText = "\(actor.name) uses \(ability.name) for \(dealt) \(ability.damageKeyword.rawValue) damage to \(abilityTarget.name)"
        } else {
            logText = "\(actor.name) uses \(ability.name) on \(abilityTarget.name)"
        }
        var appliedEffectLogs: [String] = []
        var pairedDamageHits: Set<PairedDamageHit> = []
        if ability.directDamage > 0 {
            pairedDamageHits.insert(PairedDamageHit(keyword: ability.damageKeyword, amount: ability.directDamage))
        }

        let effectsToApply: [TargetedEffect] = ability.targetedEffects.isEmpty
            ? (ability.statusApplication.map {
                [TargetedEffect(Effect.effect(from: $0), target: .abilityTarget)]
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
            case let .burn(potency):
                let skipImmediate = shouldSkipImmediateDoT(
                    potency: potency,
                    keyword: .burn,
                    pairedDamageHits: pairedDamageHits
                )
                events.append(contentsOf: applyDecayingDoT(
                    keyword: .burn,
                    potency: potency,
                    to: effectTarget,
                    sourceActorID: actor.id,
                    dealImmediateDamage: !skipImmediate
                ))
                appliedEffectLogs.append(effect.summary)

            case let .poison(potency):
                let skipImmediate = shouldSkipImmediateDoT(
                    potency: potency,
                    keyword: .poison,
                    pairedDamageHits: pairedDamageHits
                )
                events.append(contentsOf: applyDecayingDoT(
                    keyword: .poison,
                    potency: potency,
                    to: effectTarget,
                    sourceActorID: actor.id,
                    dealImmediateDamage: !skipImmediate
                ))
                appliedEffectLogs.append(effect.summary)

            case let .bleed(potency):
                let skipImmediate = shouldSkipImmediateDoT(
                    potency: potency,
                    keyword: .bleed,
                    pairedDamageHits: pairedDamageHits
                )
                events.append(contentsOf: applyBleed(
                    potency: potency,
                    to: effectTarget,
                    sourceActorID: actor.id,
                    dealImmediateDamage: !skipImmediate
                ))
                appliedEffectLogs.append(effect.summary)

            case let .prevention(keyword, _):
                guard health(for: effectTarget) > 0 else { break }
                let duration = preventionDuration(for: keyword)
                let preventionEffect = Effect.prevention(keyword, duration)
                let ae = ActiveEffect(
                    id: nextEffectID,
                    effect: preventionEffect,
                    remainingTicks: duration,
                    sourceActorID: actor.id
                )
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(effect.summary)
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
                let ae = ActiveEffect(
                    id: nextEffectID,
                    effect: effect,
                    remainingTicks: durationTicks,
                    sourceActorID: actor.id
                )
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(effect.summary)
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
                let ae = ActiveEffect(
                    id: nextEffectID,
                    effect: effect,
                    remainingTicks: durationTicks,
                    sourceActorID: actor.id
                )
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(effect.summary)
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
                appliedEffectLogs.append(effect.summary)
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
                let ae = ActiveEffect(
                    id: nextEffectID,
                    effect: effect,
                    remainingTicks: durationTicks,
                    sourceActorID: actor.id
                )
                nextEffectID += 1
                var currentEffects = effects(for: effectTarget)
                currentEffects.append(ae)
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(effect.summary)

            case let .resourceGain(keyword, amount):
                gold += amount
                appliedEffectLogs.append(effect.summary)
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
                var currentEffects = effects(for: effectTarget)

                if let removeKeyword = targetKeyword {
                    currentEffects.removeAll { $0.keyword == removeKeyword }
                } else {
                    currentEffects.removeAll { isRemovableDebuff($0.effect) }
                }

                if durationTicks > 0 {
                    let ae = ActiveEffect(
                        id: nextEffectID,
                        effect: effect,
                        remainingTicks: durationTicks,
                        sourceActorID: actor.id
                    )
                    nextEffectID += 1
                    currentEffects.append(ae)
                }
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(effect.summary)
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .cleanseApplied,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: 0,
                    keyword: targetKeyword ?? .health
                ))

            case .cleanseRandom:
                var currentEffects = effects(for: effectTarget)
                let debuffs = currentEffects.filter { isRemovableDebuff($0.effect) }
                if let removed = debuffs.randomElement() {
                    currentEffects.removeAll { $0.id == removed.id }
                }
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(effect.summary)
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .cleanseApplied,
                    actorName: actor.name,
                    abilityName: ability.name,
                    target: effectTarget,
                    amount: 0,
                    keyword: .health
                ))

            case let .dealDamage(keyword, amount):
                let (typedDamage, typedShieldEvents) = applyDamage(amount, to: effectTarget)
                events.append(contentsOf: typedShieldEvents)
                if typedDamage > 0 || amount > 0 {
                    pairedDamageHits.insert(PairedDamageHit(keyword: keyword, amount: amount))
                }
                if typedDamage > 0 {
                    events.append(nextEvent(
                        kind: .ability,
                        effectKind: nil,
                        actorName: actor.name,
                        abilityName: ability.name,
                        target: effectTarget,
                        amount: typedDamage,
                        keyword: keyword
                    ))
                    if effectTarget.id != actor.id {
                        events.append(contentsOf: applyLeechFromDamage(typedDamage, sourceActorID: actor.id))
                    }
                }
                appliedEffectLogs.append(effect.summary)

            case let .halveMitigation(keyword):
                var currentEffects = effects(for: effectTarget)
                for index in currentEffects.indices {
                    if case let .mitigation(mitigationKeyword, percent, duration) = currentEffects[index].effect,
                       mitigationKeyword == keyword {
                        currentEffects[index].effect = .mitigation(
                            mitigationKeyword,
                            percent / 2,
                            duration
                        )
                    }
                }
                setEffects(currentEffects, for: effectTarget)
                appliedEffectLogs.append(effect.summary)

            case .preventionBuildup:
                break
            }
        }

        if !appliedEffectLogs.isEmpty {
            logText += " and " + appliedEffectLogs.joined(separator: ", ")
        }
        if ability.directDamage > 0 || !appliedEffectLogs.isEmpty {
            log.append(LogEntry(id: nextEventID, text: "\(logText)."))
        } else {
            log.append(LogEntry(id: nextEventID, text: "\(actor.name) uses \(ability.name)."))
        }

        recordAction(for: actor)
        return events
    }

    private func preventionDuration(for keyword: Keyword) -> Int {
        switch keyword {
        case .freeze, .stun:
            return 1
        default:
            return 1
        }
    }

    private func shouldSkipImmediateDoT(
        potency: Int,
        keyword: Keyword,
        pairedDamageHits: Set<PairedDamageHit>
    ) -> Bool {
        pairedDamageHits.contains(PairedDamageHit(keyword: keyword, amount: potency))
    }

    private func isRemovableDebuff(_ effect: Effect) -> Bool {
        switch effect {
        case .burn, .poison, .bleed, .prevention, .preventionBuildup:
            return true
        case .shield, .mitigation, .leech, .cleanse, .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation:
            return false
        }
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

    private mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        guard health(for: effectTarget) > 0, potency > 0 else { return [] }

        var events: [ActionEvent] = []
        if dealImmediateDamage {
            events.append(contentsOf: logDoTDamage(
                applyDoTDamage(potency, keyword: keyword, to: effectTarget, sourceActorID: sourceActorID),
                keyword: keyword,
                target: effectTarget
            ))
        }

        var currentEffects = effects(for: effectTarget)
        if let index = currentEffects.firstIndex(where: { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }) {
            let existingPotency = currentEffects[index].effect.potency ?? 0
            currentEffects[index].effect = effectCase(for: keyword, potency: existingPotency + potency)
            if currentEffects[index].sourceActorID == nil {
                currentEffects[index].sourceActorID = sourceActorID
            }
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: nextEffectID,
                    effect: effectCase(for: keyword, potency: potency),
                    remainingTicks: 0,
                    sourceActorID: sourceActorID
                )
            )
            nextEffectID += 1
        }
        setEffects(currentEffects, for: effectTarget)
        return events
    }

    private mutating func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        guard health(for: effectTarget) > 0, potency > 0 else { return [] }

        var events: [ActionEvent] = []
        if dealImmediateDamage {
            events.append(contentsOf: logDoTDamage(
                applyDoTDamage(potency, keyword: .bleed, to: effectTarget, sourceActorID: sourceActorID),
                keyword: .bleed,
                target: effectTarget
            ))
        }

        var currentEffects = effects(for: effectTarget)
        currentEffects.append(
            ActiveEffect(
                id: nextEffectID,
                effect: .bleed(potency),
                remainingTicks: Effect.bleedDoTTickCount,
                sourceActorID: sourceActorID
            )
        )
        nextEffectID += 1
        setEffects(currentEffects, for: effectTarget)
        return events
    }

    private func effectCase(for keyword: Keyword, potency: Int) -> Effect {
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        default: return .poison(potency)
        }
    }

    private mutating func logDoTDamage(
        _ result: (healthLost: Int, events: [ActionEvent]),
        keyword: Keyword,
        target: Combatant
    ) -> [ActionEvent] {
        var events = result.events
        guard result.healthLost > 0 else { return events }

        let event = nextEvent(
            kind: .status,
            effectKind: nil,
            actorName: keyword.rawValue,
            abilityName: keyword.rawValue,
            target: target,
            amount: result.healthLost,
            keyword: keyword
        )
        events.append(event)
        log.append(LogEntry(
            id: event.id,
            text: "\(target.name) takes \(result.healthLost) \(keyword.rawValue) damage."
        ))
        return events
    }

    private mutating func tickEffects(_ effects: [ActiveEffect], target: Combatant) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        var remaining = effects

        guard health(for: target) > 0 else {
            return (events, remaining)
        }

        for index in remaining.indices {
            guard case let .bleed(potency) = remaining[index].effect, remaining[index].remainingTicks > 0 else {
                continue
            }

            events.append(contentsOf: logDoTDamage(
                applyDoTDamage(potency, keyword: .bleed, to: target, sourceActorID: remaining[index].sourceActorID),
                keyword: .bleed,
                target: target
            ))
            remaining[index].remainingTicks -= 1
        }

        for index in remaining.indices where remaining[index].effect.isDecayingDoT {
            let nextPotency = remaining[index].effect.potencyAfterTick()
            if nextPotency > 0 {
                events.append(contentsOf: logDoTDamage(
                    applyDoTDamage(nextPotency, keyword: remaining[index].keyword, to: target, sourceActorID: remaining[index].sourceActorID),
                    keyword: remaining[index].keyword,
                    target: target
                ))
                remaining[index].effect = effectCase(for: remaining[index].keyword, potency: nextPotency)
            } else {
                remaining[index].effect = effectCase(for: remaining[index].keyword, potency: 0)
            }
        }

        for ae in remaining {
            switch ae.effect {
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
            switch ae.effect {
            case .burn(0), .poison(0):
                return nil
            case .bleed:
                return ae.remainingTicks > 0 ? ae : nil
            case .burn, .poison:
                return ae
            case .prevention, .preventionBuildup:
                return ae
            default:
                var updated = ae
                updated.remainingTicks -= 1
                return updated.remainingTicks > 0 ? updated : nil
            }
        }

        return (events, remaining)
    }

    private func isEffectType(_ effect: Effect) -> Bool {
        switch effect {
        case .burn, .poison, .bleed, .prevention, .preventionBuildup, .shield, .mitigation, .leech, .cleanse: return true
        case .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation: return false
        }
    }

    private mutating func applyDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> (healthLost: Int, events: [ActionEvent]) {
        guard amount > 0 else { return (0, []) }

        let (healthLost, shieldEvents) = applyDamage(amount, to: combatant)
        var events = shieldEvents
        if healthLost > 0, let sourceActorID {
            events.append(contentsOf: applyLeechFromDamage(healthLost, sourceActorID: sourceActorID))
        }
        _ = keyword
        return (healthLost, events)
    }

    private mutating func applyPreventionBuildup(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> [ActionEvent] {
        guard amount > 0, health(for: combatant) > 0 else { return [] }
        if hasActivePrevention(actor: combatant) { return [] }

        let threshold = max(1, Int(ceil(Double(combatant.maxHealth) * 0.20)))
        var currentEffects = effects(for: combatant)

        let existingIndex = currentEffects.firstIndex { ae in
            if case let .preventionBuildup(k, _, _) = ae.effect, k == keyword { return true }
            return false
        }
        let existingAmount: Int = {
            guard let existingIndex,
                  case let .preventionBuildup(_, amt, _) = currentEffects[existingIndex].effect
            else { return 0 }
            return amt
        }()

        let newAmount = min(existingAmount + amount, threshold)
        var events: [ActionEvent] = []

        if newAmount >= threshold {
            if let existingIndex {
                currentEffects.remove(at: existingIndex)
            }
            let prevention = Effect.prevention(keyword, 1)
            let ae = ActiveEffect(
                id: nextEffectID,
                effect: prevention,
                remainingTicks: 1,
                sourceActorID: sourceActorID
            )
            nextEffectID += 1
            currentEffects.append(ae)
            setEffects(currentEffects, for: combatant)

            let actorName: String
            if let sourceActorID, let source = self.combatant(for: sourceActorID) {
                actorName = source.name
            } else {
                actorName = combatant.name
            }
            let abilityName = keyword.statusAlias ?? keyword.rawValue
            events.append(nextEvent(
                kind: .effect,
                effectKind: .preventionTriggered,
                actorName: actorName,
                abilityName: abilityName,
                target: combatant,
                amount: 0,
                keyword: keyword
            ))
        } else {
            let buildup = Effect.preventionBuildup(keyword, newAmount, threshold)
            if let existingIndex {
                currentEffects[existingIndex] = ActiveEffect(
                    id: currentEffects[existingIndex].id,
                    effect: buildup,
                    remainingTicks: currentEffects[existingIndex].remainingTicks,
                    sourceActorID: currentEffects[existingIndex].sourceActorID
                )
            } else {
                currentEffects.append(
                    ActiveEffect(
                        id: nextEffectID,
                        effect: buildup,
                        remainingTicks: 0,
                        sourceActorID: sourceActorID
                    )
                )
                nextEffectID += 1
            }
            setEffects(currentEffects, for: combatant)
        }

        return events
    }

    private mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        guard damage > 0, let actor = combatant(for: sourceActorID) else { return [] }

        let leechPct = effects(for: actor).reduce(0.0) { sum, activeEffect in
            if case let .leech(_, percent, _) = activeEffect.effect { return sum + percent }
            return sum
        }
        guard leechPct > 0 else { return [] }

        let restored = Int(ceil(Double(damage) * leechPct))
        guard restored > 0 else { return [] }

        applyHeal(restored, to: actor)
        return [
            nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actor.name,
                abilityName: "Leech",
                target: actor,
                amount: restored,
                keyword: .leech
            )
        ]
    }

    private func combatant(for id: String) -> Combatant? {
        if hero.id == id { return hero }
        if pet.id == id { return pet }
        if enemy.id == id { return enemy }
        return nil
    }

    private mutating func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil
    ) -> (healthLost: Int, shieldEvents: [ActionEvent]) {
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

        if amount > 0,
           let damageKeyword,
           damageKeyword == .stun || damageKeyword == .freeze,
           health(for: combatant) > 0 {
            shieldEvents.append(contentsOf: applyPreventionBuildup(
                amount,
                keyword: damageKeyword,
                to: combatant,
                sourceActorID: sourceActorID
            ))
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
