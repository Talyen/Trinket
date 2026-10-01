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

    private struct PlacementState: Hashable {
        let index: Int
        let remaining: [Int]
        let frontierTypes: [LabyrinthNodeType]
    }

    private struct PlacementSearch {
        let planned: [LabyrinthNodeType]
        let kinds: [LabyrinthNodeType]
        let positions: [LabyrinthGridPosition]
        let frontiers: [[Int]]
        var memo: [PlacementState: Int] = [:]

        func choices(from state: PlacementState) -> [LabyrinthNodeType] {
            if state.index == 0 {
                return [planned[0]]
            }
            if state.index == planned.count - 1 {
                return [planned[planned.count - 1]]
            }
            return kinds.indices.filter { state.remaining[$0] > 0 }.map { kinds[$0] }
        }

        func advance(_ state: PlacementState, type: LabyrinthNodeType) -> (PlacementState, Int) {
            let previous = Dictionary(uniqueKeysWithValues: zip(frontiers[state.index], state.frontierTypes))
            let conflicts = previous.count { index, previousType in
                previousType == type && positions[index].isAdjacent(to: positions[state.index])
            }
            var remaining = state.remaining
            if state.index > 0, state.index < planned.count - 1,
               let kind = kinds.firstIndex(of: type) {
                remaining[kind] -= 1
            }
            let next = PlacementState(
                index: state.index + 1,
                remaining: remaining,
                frontierTypes: frontiers[state.index + 1].map {
                    if $0 == state.index {
                        return type
                    }
                    guard let previousType = previous[$0] else {
                        preconditionFailure("Placement frontier must retain assigned room types")
                    }
                    return previousType
                },
            )
            return (next, conflicts)
        }

        mutating func minimumConflicts(from state: PlacementState) -> Int {
            if state.index == planned.count {
                return 0
            }
            if let cached = memo[state] {
                return cached
            }
            var best = Int.max
            for type in choices(from: state) {
                let (next, conflicts) = advance(state, type: type)
                best = min(best, conflicts + minimumConflicts(from: next))
            }
            memo[state] = best
            return best
        }
    }

    static func separatedTypes(
        _ planned: [LabyrinthNodeType],
        positions: [LabyrinthGridPosition],
        using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthNodeType] {
        guard planned.count > 2 else { return planned }
        let middle = Array(planned.dropFirst().dropLast())
        let kinds = Set(middle).sorted { $0.rawValue < $1.rawValue }
        // Hex edges only cross adjacent rows; retain only earlier rooms with an unassigned neighbor.
        let frontiers = (0 ... planned.count).map { index in
            (0 ..< index).filter { previous in
                (index ..< planned.count).contains { positions[previous].isAdjacent(to: positions[$0]) }
            }
        }
        var search = PlacementSearch(planned: planned, kinds: kinds, positions: positions, frontiers: frontiers)
        var state = PlacementState(
            index: 0, remaining: kinds.map { kind in middle.count(where: { $0 == kind }) }, frontierTypes: [],
        )
        var result: [LabyrinthNodeType] = []
        while state.index < planned.count {
            let best = search.minimumConflicts(from: state)
            var optimal: [LabyrinthNodeType] = []
            for type in search.choices(from: state) {
                let (next, conflicts) = search.advance(state, type: type)
                if conflicts + search.minimumConflicts(from: next) == best {
                    optimal.append(type)
                }
            }
            guard let type = optimal.randomElement(using: &rng) else {
                preconditionFailure("Room counts must permit an optimal placement")
            }
            result.append(type)
            state = search.advance(state, type: type).0
        }
        return result
    }
}
