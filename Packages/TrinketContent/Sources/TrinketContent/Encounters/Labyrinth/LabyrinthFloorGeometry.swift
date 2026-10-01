import Foundation

/// Samples connected layouts using only the current row as the graph frontier.
enum LabyrinthFloorGeometry {
    private struct State: Hashable {
        let row: Int
        let columns: [Int]
        let degrees: [Int]
        let components: [Int]
        let doubles: Int
        let cycles: Int
        let hasJunction: Bool
    }

    private struct Search {
        let rowCount: Int
        let doubleCount: Int
        let cycleCount: Int
        var memo: [State: UInt64] = [:]

        mutating func completions(from state: State) -> UInt64 {
            if state.row == rowCount - 1 {
                return state.doubles == doubleCount && state.cycles == cycleCount
                    && state.degrees == [1] && state.components == [0]
                    && state.hasJunction ? 1 : 0
            }
            if let cached = memo[state] {
                return cached
            }
            let count = successors(of: state).reduce(UInt64(0)) { total, next in
                total + completions(from: next)
            }
            memo[state] = count
            return count
        }

        func successors(of state: State) -> [State] {
            let row = state.row + 1
            let columns = (-LabyrinthMapLayout.maxProjectedHalfColumn ... LabyrinthMapLayout.maxProjectedHalfColumn)
                .filter { ($0 - row).isMultiple(of: 2) }
            var choices = columns.map { [$0] }
            if row < rowCount - 1 {
                for i in columns.indices {
                    for j in columns.indices where j > i {
                        choices.append([columns[i], columns[j]])
                    }
                }
            }
            return choices.compactMap { nextState(from: state, columns: $0) }
        }

        private func nextState(from state: State, columns: [Int]) -> State? {
            let doubles = state.doubles + (columns.count == 2 ? 1 : 0)
            let remainingMiddleRows = max(0, rowCount - state.row - 3)
            guard doubles <= doubleCount, doubles + remainingMiddleRows >= doubleCount else { return nil }

            let oldCount = state.columns.count
            var labels = state.components + columns.indices.map { $0 + oldCount }
            var oldDegrees = state.degrees
            var degrees = Array(repeating: 0, count: columns.count)
            var cycles = state.cycles
            func connect(_ a: Int, _ b: Int) {
                if labels[a] == labels[b] {
                    cycles += 1
                } else {
                    let replaced = labels[b]
                    let replacement = labels[a]
                    labels = labels.map { $0 == replaced ? replacement : $0 }
                }
            }
            for i in state.columns.indices {
                for j in columns.indices where abs(state.columns[i] - columns[j]) == 1 {
                    oldDegrees[i] += 1
                    degrees[j] += 1
                    connect(i, oldCount + j)
                }
            }
            if columns.count == 2, columns[1] - columns[0] == 2 {
                degrees[0] += 1
                degrees[1] += 1
                connect(oldCount, oldCount + 1)
            }
            guard cycles <= cycleCount,
                  oldDegrees.allSatisfy({ $0 <= 4 }),
                  degrees.allSatisfy({ $0 <= 4 }),
                  state.row != 0 || oldDegrees == [1]
            else { return nil }

            // A component leaving the frontier can never reconnect on a later row.
            let nextLabels = Array(labels.dropFirst(oldCount))
            guard labels.prefix(oldCount).allSatisfy(nextLabels.contains) else { return nil }
            var canonical: [Int: Int] = [:]
            let components = nextLabels.map { label in
                if let existing = canonical[label] {
                    return existing
                }
                let next = canonical.count
                canonical[label] = next
                return next
            }
            return State(
                row: state.row + 1,
                columns: columns,
                degrees: degrees,
                components: components,
                doubles: doubles,
                cycles: cycles,
                hasJunction: state.hasJunction || oldDegrees.contains(where: { $0 >= 3 }),
            )
        }
    }

    static func positions(
        nodeCount: Int,
        using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthGridPosition] {
        let roll = Int.random(in: 0 ..< 5, using: &rng)
        let rowCount = (2 * nodeCount + 1) / 3
        var search = Search(
            rowCount: rowCount,
            doubleCount: nodeCount - rowCount,
            cycleCount: roll < 3 ? 0 : roll - 2,
        )
        var state = State(
            row: 0, columns: [0], degrees: [0], components: [0],
            doubles: 0, cycles: 0, hasJunction: false,
        )
        var positions = [LabyrinthGridPosition(row: 0, column: 0)]
        while state.row < rowCount - 1 {
            let total = search.completions(from: state)
            precondition(total > 0, "Labyrinth floor constraints must produce a layout")
            var ticket = UInt64.random(in: 0 ..< total, using: &rng)
            for next in search.successors(of: state) {
                let count = search.completions(from: next)
                if ticket < count {
                    state = next
                    positions += next.columns.map {
                        LabyrinthGridPosition(row: next.row, column: ($0 - next.row) / 2)
                    }
                    break
                }
                ticket -= count
            }
        }
        return positions
    }
}
