/// Activation allowances are partitioned by lifetime. Ending a nested action
/// releases only its bucket, without rebuilding battle, turn, or parent claims.
struct CombatActivationLedger {
    enum Claim: Hashable {
        case talent(CombatActivationClaim)
        case heroTalent(CombatActivationClaim)
        case heroCard(CombatActivationClaim)
        case affix(CombatActivationClaim)
    }

    enum Cadence: Hashable {
        case battle
        case turn(Int)
        case action(Int)
        case standaloneAction(Int)
        case standaloneRestoration(Int)
        case card(Int)
    }

    private struct Key: Hashable {
        let claim: Claim
        let actorID: String
    }

    private var buckets: [Cadence: Set<Key>] = [:]
    private var turn: Int?
    private var standaloneAction: Int?

    func contains(_ claim: Claim, actorID: String, cadence: Cadence) -> Bool {
        buckets[cadence]?.contains(Key(claim: claim, actorID: actorID)) == true
    }

    mutating func claim(_ claim: Claim, actorID: String, cadence: Cadence) -> Bool {
        // Turn and standalone-action allowances roll over lazily on the first
        // claim, matching their existing cadence semantics. Nested frames retain
        // separate buckets until their explicit completion.
        switch cadence {
        case let .turn(id):
            if turn != id {
                if let turn {
                    finish(.turn(turn))
                }
                turn = id
            }
        case let .standaloneAction(id):
            if standaloneAction != id {
                if let standaloneAction {
                    finish(.standaloneAction(standaloneAction))
                }
                standaloneAction = id
            }
        case .battle, .action, .card, .standaloneRestoration:
            break
        }
        return buckets[cadence, default: []].insert(Key(claim: claim, actorID: actorID)).inserted
    }

    mutating func finish(_ cadence: Cadence) {
        buckets.removeValue(forKey: cadence)
    }
}
