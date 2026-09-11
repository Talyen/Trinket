import TrinketCore

struct CombatResolution {
    var feedbackGroupID: Int?
    var isAdvancingEffects = false

    mutating func beginFeedbackGroup(eventID: Int) -> Int? {
        let previous = feedbackGroupID
        feedbackGroupID = previous ?? eventID
        return previous
    }

    enum Scope: Hashable {
        case damage, dot, dotMirror, draw, heroReaction, uniqueReaction, talentReaction, detonation
    }

    enum Claim: Hashable {
        case talent(TalentClaim)
        case heroTalent(String)
        case heroCard(String)
    }

    enum Cadence: Hashable {
        case battle
        case turn(Int)
        case action(Int)
        case standaloneAction(Int)
        case card(Int)
    }

    private struct ClaimKey: Hashable {
        let claim: Claim
        let actorID: String
        let cadence: Cadence
    }

    private struct Action {
        let id: Int
        let context: BattleActionContext
        let origin: DamageOperation.AttackOrigin
        var outcome: ResolvedActionFacts?
        var talents: TalentActionFacts?
    }

    private struct Card {
        let id: Int
        let actorID: String
        var outcome: ResolvedActionFacts?
        var talents: HeroTalentCardFacts?
    }

    private enum Frame {
        case action(Action)
        case automaticPlay
    }

    private var depths: [Scope: Int] = [:]
    private var frames: [Frame] = []
    private var nextActionID = 0
    private var cards: [Card] = []
    private(set) var nextCardID = 0
    private var claims: Set<ClaimKey> = []

    var actionID: Int? {
        currentAction?.id
    }

    var actionContext: BattleActionContext? {
        currentAction?.context
    }

    var attackOrigin: DamageOperation.AttackOrigin {
        currentAction?.origin ?? .ability
    }

    private var currentAction: Action? {
        for frame in frames.reversed() {
            if case let .action(action) = frame {
                return action
            }
        }
        return nil
    }

    var actionOutcome: ResolvedActionFacts? {
        currentAction?.outcome
    }

    var isAutomaticPlay: Bool {
        frames.contains { frame in
            switch frame {
            case .automaticPlay: true
            case let .action(action): action.origin == .counterattack
            }
        }
    }

    mutating func beginAutomaticPlay() {
        frames.append(.automaticPlay)
    }

    mutating func endAutomaticPlay() {
        guard case .automaticPlay = frames.removeLast() else { preconditionFailure() }
    }

    func cardOutcome(for actorID: String) -> ResolvedActionFacts? {
        guard cards.last?.actorID == actorID else { return nil }
        return cards.last?.outcome
    }

    var cardTalents: HeroTalentCardFacts? {
        cards.last(where: { $0.talents != nil })?.talents
    }

    mutating func beginCard(actorID: String, tier: AbilityTier, previousDamageKeywords: Set<Keyword>) -> Int {
        let id = nextCardID
        nextCardID += 1
        var talents = HeroTalentCardFacts(actorID: actorID, tier: tier)
        talents.playSerial = id
        talents.previousDamageKeywords = previousDamageKeywords
        cards.append(Card(id: id, actorID: actorID, talents: talents))
        return id
    }

    mutating func mutateCardTalents(_ body: (inout HeroTalentCardFacts) -> Void) {
        guard let index = cards.lastIndex(where: { $0.talents != nil }),
              var talents = cards[index].talents else { return }
        body(&talents)
        cards[index].talents = talents
    }

    mutating func finishCardTalents() -> HeroTalentCardFacts? {
        guard let index = cards.lastIndex(where: { $0.talents != nil }) else { return nil }
        defer { cards[index].talents = nil }
        return cards[index].talents
    }

    mutating func prepareActionTalents(_ talents: TalentActionFacts) {
        guard case var .action(action) = frames.last else { preconditionFailure() }
        precondition(action.talents == nil && action.context.actor.id == talents.actorID)
        action.talents = talents
        frames[frames.count - 1] = .action(action)
    }

    mutating func consumeAttackReduction(for actorID: String?, damage: Int) -> Int {
        mutateActionTalents(for: actorID) { talents in
            let reduction = min(max(0, damage), talents.blindingReduction)
            talents.blindingReduction -= reduction
            return reduction
        } ?? 0
    }

    mutating func consumeGoldDamage(for actorID: String?) -> Int {
        mutateActionTalents(for: actorID) { talents in
            defer { talents.goldDamage = 0 }
            return talents.goldDamage
        } ?? 0
    }

    private mutating func mutateActionTalents<Value>(
        for actorID: String?,
        _ body: (inout TalentActionFacts) -> Value,
    ) -> Value? {
        guard let index = frames.lastIndex(where: { frame in
            if case let .action(action) = frame {
                return action.talents != nil
            }
            return false
        }), case var .action(action) = frames[index],
        var talents = action.talents, talents.actorID == actorID else { return nil }
        let value = body(&talents)
        action.talents = talents
        frames[index] = .action(action)
        return value
    }

    mutating func prepareAction(_ facts: ResolvedActionFacts) -> Bool {
        guard case var .action(action) = frames.last else { preconditionFailure() }
        action.outcome = facts
        frames[frames.count - 1] = .action(action)
        guard cards.last?.actorID == facts.action.actor.id, cards.last?.outcome == nil,
              facts.origin == .card || facts.origin == .ordinaryCard else { return false }
        cards[cards.count - 1].outcome = facts
        return true
    }

    func depth(_ scope: Scope) -> Int {
        depths[scope, default: 0]
    }

    mutating func enter(_ scope: Scope) {
        depths[scope, default: 0] += 1
    }

    mutating func leave(_ scope: Scope) {
        precondition(depth(scope) > 0)
        depths[scope, default: 0] -= 1
    }

    mutating func beginAction(_ context: BattleActionContext, origin: DamageOperation.AttackOrigin) {
        frames.append(.action(Action(id: nextActionID, context: context, origin: origin)))
        nextActionID += 1
    }

    mutating func endAction() {
        guard case let .action(action) = frames.removeLast() else { preconditionFailure() }
        claims = claims.filter { $0.cadence != .action(action.id) }
    }

    mutating func endCard(_ id: Int) {
        precondition(cards.last?.id == id)
        cards.removeLast()
        claims = claims.filter { $0.cadence != .card(id) }
    }

    mutating func claim(_ claim: Claim, actorID: String, cadence: Cadence) -> Bool {
        if case let .turn(turn) = cadence {
            claims = claims.filter {
                if case let .turn(previous) = $0.cadence {
                    return previous == turn
                }
                return true
            }
        }
        if case let .standaloneAction(action) = cadence {
            claims = claims.filter {
                if case let .standaloneAction(previous) = $0.cadence {
                    return previous == action
                }
                return true
            }
        }
        return claims.insert(ClaimKey(claim: claim, actorID: actorID, cadence: cadence)).inserted
    }
}

enum CombatResolver {
    static func damage(_ request: DamageRequest, in context: inout BattleState) -> CombatOutcome {
        guard request.amount > 0 else { return .empty }
        guard context.resolution.depth(.damage) < ReactionScope.maxTalentReactionDepth else {
            ReactionScope.capHit(site: "damage", depth: context.resolution.depth(.damage))
            return .empty
        }
        context.resolution.enter(.damage)
        defer { context.resolution.leave(.damage) }
        var state = DamageResolutionState(
            amount: request.amount, combatant: request.target, sourceActorID: request.sourceActorID,
            damageKeyword: request.keyword, options: request.options,
        )
        DamagePipeline.run(state: &state, in: &context)
        return CombatOutcome.fromDamage(state: state)
    }
}
