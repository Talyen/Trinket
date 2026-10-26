import TrinketCore

public enum ResourceTransmutation {
    public static func canApply(
        from source: HomesteadResource, to destination: HomesteadResource, quantity: Int,
        homestead: PlayerHomesteadState, gold: Int,
    ) -> Bool {
        guard homestead.tier(for: .transmutationCrucible) > 0,
              source != destination, quantity == 1 || quantity == 10,
              homestead.balance(for: source, gold: gold) >= quantity else { return false }
        let balance = homestead.balance(for: destination, gold: gold)
        if destination == .gold {
            return balance >= 0 && PlayerRosterState.availableGoldCapacity(
                gold: gold, reservedGold: PlayerRosterState.reservedGold(from: homestead.pendingProduction),
            ) >= quantity
        }
        return balance >= 0 && balance <= Int.max - quantity
    }

    public static func apply(
        from source: HomesteadResource, to destination: HomesteadResource, quantity: Int,
        homestead: inout PlayerHomesteadState, gold: inout Int,
    ) -> Bool {
        guard canApply(from: source, to: destination, quantity: quantity, homestead: homestead, gold: gold) else { return false }
        homestead.deductCost([ResourceAmount(source, quantity)], gold: &gold)
        if destination == .gold {
            gold += quantity
        } else {
            homestead.resources[destination, default: 0] += quantity
        }
        return true
    }
}
