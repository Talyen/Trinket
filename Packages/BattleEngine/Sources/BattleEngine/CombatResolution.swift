struct CombatResolution {
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
    }

    private struct Card {
        let id: Int
        let actorID: String
        var outcome: ResolvedActionFacts?
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

    mutating func beginCard(actorID: String) -> Int {
        let id = nextCardID
        nextCardID += 1
        cards.append(Card(id: id, actorID: actorID))
        return id
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
