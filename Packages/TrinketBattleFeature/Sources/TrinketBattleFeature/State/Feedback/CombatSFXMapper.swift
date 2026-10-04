import BattleEngine
import TrinketContent
import TrinketCore

enum CombatSFXMapper {
    static let battlePrewarmIDs = [
        SFXID.abilityDraw, SFXID.hit, SFXID.hitBurn, SFXID.hitFreeze, SFXID.hitStun,
        SFXID.hitPiercing, SFXID.hitHoly, SFXID.heal, SFXID.buff, SFXID.block,
        SFXID.blockAbsorb, SFXID.dodge, SFXID.restoreMana, SFXID.lootCollect,
        SFXID.controlFreeze, SFXID.controlStun, SFXID.purge, SFXID.deathsDoor,
        SFXID.victory, SFXID.defeat,
    ]

    private enum NumericKind: Int, Hashable {
        case damage, heal, blockGain, blockAbsorption

        var priority: Int {
            self == .blockAbsorption ? Self.blockGain.rawValue : rawValue
        }
    }

    private struct NumericKey: Hashable {
        let kind: NumericKind
        let keyword: Keyword
    }

    private struct DamageKey: Hashable {
        let targetID: String
        let keyword: Keyword
    }

    private struct Candidate {
        let clipID: String
        let priority: Int
        let order: Int
        var strength = 0

        func precedes(_ other: Self) -> Bool {
            priority == other.priority ? order < other.order : priority < other.priority
        }
    }

    private struct Selection {
        var numeric: [NumericKey: Candidate] = [:]
        var overrideCue: Candidate?
        var fallback: Candidate?

        mutating func add(_ amount: Int, kind: NumericKind, keyword: Keyword, clip: String, order: Int) {
            guard amount > 0 else { return }
            let key = NumericKey(kind: kind, keyword: keyword)
            if numeric[key] != nil {
                numeric[key]?.strength += amount
            } else {
                numeric[key] = Candidate(clipID: clip, priority: kind.priority, order: order, strength: amount)
            }
        }

        mutating func offer(_ clip: String, priority: Int, order: Int, isOverride: Bool = false) {
            let candidate = Candidate(clipID: clip, priority: priority, order: order)
            if isOverride {
                if overrideCue.map({ candidate.precedes($0) }) ?? true {
                    overrideCue = candidate
                }
            } else if fallback.map({ candidate.precedes($0) }) ?? true {
                fallback = candidate
            }
        }

        var clipID: String? {
            if let overrideCue {
                return overrideCue.clipID
            }
            let strongest = numeric.values.min { lhs, rhs in
                lhs.strength == rhs.strength ? lhs.precedes(rhs) : lhs.strength > rhs.strength
            }
            return strongest?.clipID ?? fallback?.clipID
        }
    }

    static func clipID(
        for events: [ActionEvent],
        damage: [BattleResolvedDamage] = [],
        didDrawCards: Bool = false,
    ) -> String? {
        var selection = Selection()
        let recorded = Set(damage.map { DamageKey(targetID: $0.targetID, keyword: $0.keyword) })
        for (index, hit) in damage.enumerated() {
            let order = events.firstIndex {
                $0.targetID == hit.targetID && $0.keyword == hit.keyword && isDamageEvent($0)
            } ?? (events.count + index)
            switch hit.impact {
            case .dodged:
                selection.offer(SFXID.dodge, priority: 0, order: order)
            case let .landed(blocked, healthLost):
                selection.add(healthLost, kind: .damage, keyword: hit.keyword, clip: damageClipID(hit.keyword), order: order)
                let absorptionOrder = events.firstIndex { $0.effectKind == .shieldAbsorbed } ?? order
                selection.add(blocked, kind: .blockAbsorption, keyword: .block, clip: SFXID.blockAbsorb, order: absorptionOrder)
            }
        }
        for (order, event) in events.enumerated() {
            add(event, order: order, events: events, recorded: recorded, to: &selection)
        }
        if didDrawCards {
            selection.offer(SFXID.abilityDraw, priority: 4, order: events.count)
        }
        return selection.clipID
    }

    private static func isDamageEvent(_ event: ActionEvent) -> Bool {
        event.kind == .abilityDamage || event.kind == .status
            || event.effectKind == .thornsTriggered || event.effectKind == .hemorrhageTriggered
    }

    private static func isCardEffect(_ event: ActionEvent, in events: [ActionEvent]) -> Bool {
        event.origin == .direct || events.contains {
            $0.kind == .ability && $0.feedbackGroupID == event.feedbackGroupID
                && $0.actorName == event.actorName && $0.abilityName == event.abilityName
        }
    }

    private static func add(
        _ event: ActionEvent,
        order: Int,
        events: [ActionEvent],
        recorded: Set<DamageKey>,
        to selection: inout Selection,
    ) {
        let key = DamageKey(targetID: event.targetID, keyword: event.keyword)
        if isDamageEvent(event) {
            // Structured impacts omit Health costs and already include immediate retaliation/DoT damage.
            let isHealthCost = event.kind == .abilityDamage && !event.actorID.isEmpty && event.actorID == event.targetID
            if !isHealthCost, !recorded.contains(key) {
                selection.add(event.amount, kind: .damage, keyword: event.keyword, clip: damageClipID(event.keyword), order: order)
            }
            return
        }
        guard event.kind == .effect, let effect = event.effectKind else { return }
        switch effect {
        case .deathsDoorTriggered, .deathsDoorExpired:
            selection.offer(SFXID.deathsDoor, priority: 0, order: order, isOverride: true)
        case .controlTriggered where event.keyword == .freeze || event.keyword == .stun:
            selection.offer(
                event.keyword == .freeze ? SFXID.controlFreeze : SFXID.controlStun,
                priority: 1, order: order, isOverride: true,
            )
        case .instantHeal, .leechHeal:
            selection.add(event.amount, kind: .heal, keyword: .health, clip: SFXID.heal, order: order)
            selection.offer(SFXID.heal, priority: 2, order: order)
        case .overheal:
            if event.amount > 0 {
                selection.offer(SFXID.heal, priority: 2, order: order)
            }
        case .shieldAbsorbed:
            // Block logs name the pool owner/Block keyword, including borrowed ally protection.
            // Recorded impacts already contain the combined absorption regardless of that identity.
            if recorded.isEmpty {
                selection.add(event.amount, kind: .blockAbsorption, keyword: .block, clip: SFXID.blockAbsorb, order: order)
            }
        case .shieldApplied:
            if isCardEffect(event, in: events) {
                selection.add(event.amount, kind: .blockGain, keyword: .block, clip: SFXID.block, order: order)
            }
        default:
            addFallback(event, order: order, events: events, to: &selection)
        }
    }

    private static func addFallback(_ event: ActionEvent, order: Int, events: [ActionEvent], to selection: inout Selection) {
        switch event.effectKind {
        case .dodgeApplied:
            selection.offer(SFXID.dodge, priority: 0, order: order)
        case .cleanseApplied:
            if isCardEffect(event, in: events) {
                selection.offer(SFXID.heal, priority: 1, order: order)
            }
        case .purgeApplied:
            if isCardEffect(event, in: events) {
                selection.offer(SFXID.purge, priority: 1, order: order)
            }
        case .resourceGain:
            if event.amount > 0, isCardEffect(event, in: events), event.keyword == .mana || event.keyword == .gold {
                selection.offer(event.keyword == .mana ? SFXID.restoreMana : SFXID.lootCollect, priority: 3, order: order)
            }
        case .cardsDrawn:
            if event.amount > 0 {
                selection.offer(SFXID.abilityDraw, priority: 4, order: order)
            }
        case .controlActionSkipped where event.keyword != .freeze && event.keyword != .stun:
            selection.offer(SFXID.controlStun, priority: 2, order: order)
        case .partyDamagePreparationApplied, .leechApplied, .thornsApplied, .criticalChanceApplied,
             .manaShieldApplied, .damageKeywordOverrideApplied, .nextHolyStrikeApplied, .nextStrikeDoubleApplied,
             .nextBurnBonusApplied, .evadeNextHitApplied, .wardApplied, .avatarApplied:
            if isCardEffect(event, in: events) {
                selection.offer(SFXID.buff, priority: 2, order: order)
            }
        default:
            break
        }
    }

    private static func damageClipID(_ keyword: Keyword) -> String {
        switch keyword {
        case .burn: SFXID.hitBurn
        case .freeze: SFXID.hitFreeze
        case .stun: SFXID.hitStun
        case .holy: SFXID.hitHoly
        case .poison, .bleed: SFXID.hitPiercing
        case .physical, .leech, .thorns, .health, .gold, .block, .dodge, .purge, .cleanse, .mana, .deathsDoor: SFXID.hit
        }
    }
}
