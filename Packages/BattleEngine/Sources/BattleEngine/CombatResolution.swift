struct CombatResolution {
    enum Scope: Hashable {
        case damage, dot, draw, heroReaction, uniqueReaction, talentReaction, detonation
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
    }

    private var depths: [Scope: Int] = [:]
    private var actions: [Action] = []
    private var nextActionID = 0
    private var claims: Set<ClaimKey> = []

    var actionID: Int? {
        actions.last?.id
    }

    var actionContext: BattleActionContext? {
        actions.last?.context
    }

    var attackOrigin: DamageOperation.AttackOrigin {
        actions.last?.origin ?? .ability
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
        actions.append(Action(id: nextActionID, context: context, origin: origin))
        nextActionID += 1
    }

    mutating func endAction() {
        let action = actions.removeLast()
        claims = claims.filter { $0.cadence != .action(action.id) }
    }

    mutating func endCard(_ id: Int) {
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
