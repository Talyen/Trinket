import Foundation

/// Plans room kinds after a shape is selected; the caller owns seed and payloads.
enum LabyrinthFloorTypePlacement {
    static func plannedTypes(
        count: Int,
        hasEligibleRecruit: Bool,
        using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthNodeType] {
        var nonCombat: [LabyrinthNodeType] = [.shop, .mystery]
        if hasEligibleRecruit {
            nonCombat.append(.recruit)
        }
        nonCombat.shuffle(using: &rng)

        var middle = Array(nonCombat.prefix(min(3, count - 2)))
        var weighted: [LabyrinthNodeType] = [.battle, .battle, .battle, .mystery, .mystery, .shop]
        if hasEligibleRecruit, !middle.contains(.recruit) {
            weighted.append(.recruit)
        }
        while middle.count < count - 2 {
            let next = weighted.randomElement(using: &rng) ?? .battle
            if [.shop, .recruit].contains(next), middle.contains(next) {
                middle.append(.battle)
            } else {
                middle.append(next)
            }
        }
        middle.shuffle(using: &rng)
        return [.battle] + middle + [.boss]
    }

    static func separatedTypes(
        _ planned: [LabyrinthNodeType],
        positions: [LabyrinthGridPosition],
        using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthNodeType] {
        guard planned.count > 2 else { return planned }
        let entry = planned[0]
        let boss = planned[planned.count - 1]
        let pairs = adjacentIndexPairs(in: positions)
        func conflictCount(_ middle: [LabyrinthNodeType]) -> Int {
            let full = [entry] + middle + [boss]
            return pairs.count { pair in full[pair.0] == full[pair.1] }
        }
        var current = planned[1 ..< planned.count - 1].sorted { $0.rawValue < $1.rawValue }
        var best = current
        var bestScore = conflictCount(current)
        var tieCount = 1
        while nextPermutation(&current) {
            let score = conflictCount(current)
            if score < bestScore {
                best = current
                bestScore = score
                tieCount = 1
            } else if score == bestScore {
                tieCount += 1
                if Int.random(in: 1 ... tieCount, using: &rng) == 1 {
                    best = current
                }
            }
        }
        return [entry] + best + [boss]
    }

    private static func adjacentIndexPairs(in positions: [LabyrinthGridPosition]) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        for i in positions.indices {
            for j in positions.indices where j > i && positions[i].isAdjacent(to: positions[j]) {
                pairs.append((i, j))
            }
        }
        return pairs
    }

    private static func nextPermutation(_ values: inout [LabyrinthNodeType]) -> Bool {
        guard values.count > 1 else { return false }
        var pivot = values.count - 2
        while values[pivot].rawValue >= values[pivot + 1].rawValue {
            guard pivot > 0 else { return false }
            pivot -= 1
        }
        var successor = values.count - 1
        while values[successor].rawValue <= values[pivot].rawValue {
            successor -= 1
        }
        values.swapAt(pivot, successor)
        var lower = pivot + 1
        var upper = values.count - 1
        while lower < upper {
            values.swapAt(lower, upper)
            lower += 1
            upper -= 1
        }
        return true
    }
}
