import Foundation

/// Generates each candidate shape once, then buckets valid shapes by cycle count.
enum LabyrinthFloorGeometry {
    private struct LayoutKey: Hashable {
        let nodeCount: Int
        let cycleCount: Int
    }

    private static let validLayoutsByKey: [LayoutKey: [[LabyrinthGridPosition]]] = {
        var result: [LayoutKey: [[LabyrinthGridPosition]]] = [:]
        let entrance = LabyrinthGridPosition(row: 0, column: 0)

        for nodeCount in 7 ... 9 {
            let middleCount = nodeCount - 2
            for cycleCount in 0 ... 2 {
                result[LayoutKey(nodeCount: nodeCount, cycleCount: cycleCount)] = []
            }
            for depth in 4 ... 6 {
                let middleCandidates = (1 ..< depth).flatMap(boundedPositions(in:))
                guard middleCandidates.count >= middleCount else { continue }

                for boss in boundedPositions(in: depth) {
                    for middle in combinations(of: middleCandidates, choosing: middleCount) {
                        let positions = [entrance] + middle + [boss]
                        guard let cycleCount = validCycleCount(of: positions),
                              (0 ... 2).contains(cycleCount) else { continue }
                        let key = LayoutKey(nodeCount: nodeCount, cycleCount: cycleCount)
                        result[key, default: []].append(
                            [entrance]
                                + middle.sorted(by: LabyrinthGridPosition.isOrderedBefore)
                                + [boss],
                        )
                    }
                }
            }
        }
        return result
    }()

    static func positions(
        nodeCount: Int,
        using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthGridPosition] {
        let roll = Int.random(in: 0 ..< 5, using: &rng)
        let cycleCount = roll < 3 ? 0 : roll - 2
        let key = LayoutKey(nodeCount: nodeCount, cycleCount: cycleCount)
        guard let layouts = validLayoutsByKey[key],
              let selected = layouts.randomElement(using: &rng)
        else { preconditionFailure("Labyrinth floor constraints must produce a layout") }
        return selected
    }

    private static func boundedPositions(in row: Int) -> [LabyrinthGridPosition] {
        let bound = LabyrinthMapLayout.maxProjectedHalfColumn
        return (-bound ... bound).compactMap { projectedColumn in
            guard (projectedColumn - row).isMultiple(of: 2) else { return nil }
            return LabyrinthGridPosition(
                row: row,
                column: (projectedColumn - row) / 2,
            )
        }
    }

    private static func combinations(
        of positions: [LabyrinthGridPosition],
        choosing count: Int,
    ) -> [[LabyrinthGridPosition]] {
        guard count > 0 else { return [[]] }
        guard positions.count >= count else { return [] }

        var result: [[LabyrinthGridPosition]] = []
        var selection: [LabyrinthGridPosition] = []

        func appendCombinations(startingAt index: Int) {
            if selection.count == count {
                result.append(selection)
                return
            }
            let remainingNeeded = count - selection.count
            guard positions.count - index >= remainingNeeded else { return }
            for candidateIndex in index ... positions.count - remainingNeeded {
                selection.append(positions[candidateIndex])
                appendCombinations(startingAt: candidateIndex + 1)
                selection.removeLast()
            }
        }

        appendCombinations(startingAt: 0)
        return result
    }

    private static func validCycleCount(of positions: [LabyrinthGridPosition]) -> Int? {
        let degrees = positions.map { source in
            positions.count(where: { target in
                source != target && source.isAdjacent(to: target)
            })
        }
        guard degrees.first == 1,
              degrees.last == 1,
              degrees.allSatisfy({ $0 <= 4 }),
              degrees.contains(where: { $0 >= 3 })
        else { return nil }

        var reached: Set<LabyrinthGridPosition> = [positions[0]]
        var frontier = [positions[0]]
        while let source = frontier.popLast() {
            for target in positions where source.isAdjacent(to: target) && reached.insert(target).inserted {
                frontier.append(target)
            }
        }
        guard reached.count == positions.count else { return nil }

        let edgeCount = degrees.reduce(0, +) / 2
        return edgeCount - positions.count + 1
    }
}
