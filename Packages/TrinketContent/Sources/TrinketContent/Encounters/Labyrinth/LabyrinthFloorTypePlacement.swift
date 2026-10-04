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

    private struct PlacementFrontier {
        let adjacentOffsets: [Int]
        /// nil marks the room assigned on this step; other offsets retain an earlier room.
        let nextOffsets: [Int?]

        init(index: Int, positions: [LabyrinthGridPosition], current: [Int], next: [Int]) {
            adjacentOffsets = current.indices.filter {
                positions[current[$0]].isAdjacent(to: positions[index])
            }
            nextOffsets = next.map { previous in
                guard previous != index else { return nil }
                guard let offset = current.firstIndex(of: previous) else {
                    preconditionFailure("Placement frontier must retain assigned room types")
                }
                return offset
            }
        }
    }

    private struct PlacementSearch {
        let planned: [LabyrinthNodeType]
        let kinds: [LabyrinthNodeType]
        let frontiers: [PlacementFrontier]
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
            let frontier = frontiers[state.index]
            let conflicts = frontier.adjacentOffsets.count {
                state.frontierTypes[$0] == type
            }
            var remaining = state.remaining
            if state.index > 0, state.index < planned.count - 1,
               let kind = kinds.firstIndex(of: type) {
                remaining[kind] -= 1
            }
            let next = PlacementState(
                index: state.index + 1,
                remaining: remaining,
                frontierTypes: frontier.nextOffsets.map { offset in
                    offset.map { state.frontierTypes[$0] } ?? type
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
        let transitions = (0 ..< planned.count).map { index in
            PlacementFrontier(
                index: index, positions: positions, current: frontiers[index], next: frontiers[index + 1],
            )
        }
        var search = PlacementSearch(planned: planned, kinds: kinds, frontiers: transitions)
        var state = PlacementState(
            index: 0, remaining: kinds.map { kind in middle.count(where: { $0 == kind }) }, frontierTypes: [],
        )
        var result: [LabyrinthNodeType] = []
        while state.index < planned.count {
            let best = search.minimumConflicts(from: state)
            var optimal: [(type: LabyrinthNodeType, state: PlacementState)] = []
            for type in search.choices(from: state) {
                let (next, conflicts) = search.advance(state, type: type)
                if conflicts + search.minimumConflicts(from: next) == best {
                    optimal.append((type, next))
                }
            }
            guard let selected = optimal.randomElement(using: &rng) else {
                preconditionFailure("Room counts must permit an optimal placement")
            }
            result.append(selected.type)
            state = selected.state
        }
        return result
    }
}
