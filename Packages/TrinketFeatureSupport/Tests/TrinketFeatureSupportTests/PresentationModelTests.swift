import CoreGraphics
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketPersistenceTestSupport
@testable import TrinketFeatureAdapters
@testable import TrinketFeatureSupport

struct PresentationModelTests {
    #if DEBUG
    @Test @MainActor func `failed combatant edits preserve the roster and retry persists`() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "CombatantEdits")
        defer { SaveTestSupport.removeTempDirectory(directory) }
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        let hero = try #require(GameContent.hero(matching: "knight"))
        let item = try SaveTestSupport.makeGeneratedItem(baseID: "longsword", rarity: .basic)
        let node = try #require(CombatantTalentCatalog.configIfAvailable(for: hero.id)?.trees.first?.nodes.first)
        try playerSave.performBatchMutation { save in
            save.roster = .testSeed
            save.roster.progressions[hero.id] = .at(level: 2)
            save.roster.setEquipmentLoadout(.init(), for: hero)
            save.roster.setLoadout(save.roster.loadout(for: hero).selecting(.bash), for: hero)
            save.roster.setUnlockedTalents([node.id], for: hero)
            save.inventory.items = [item]
        }
        let commands: [CombatantDetailEdit] = [.selectAbility(.slash), .equipItem(item, .weapon), .unequipItem(.weapon), .resetTalents]
        for command in commands {
            let before = playerSave.roster
            playerSave.forcesNextSaveFailure = true
            #expect(!command.apply(to: playerSave, for: hero))
            #expect(playerSave.roster == before)
            #expect(command.apply(to: playerSave, for: hero))
            let reloaded = try SaveTestSupport.makeSaveStore(directoryURL: directory)
            #expect(reloaded.roster == playerSave.roster)
            switch command {
            case .selectAbility:
                #expect(reloaded.roster.loadout(for: hero).basic?.id == Ability.slash.id)
            case .equipItem:
                #expect(reloaded.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == item.id)
            case .unequipItem:
                #expect(reloaded.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == nil)
            case .resetTalents:
                #expect(reloaded.roster.unlockedTalents(for: hero).isEmpty)
            }
        }
    }
    #endif

    @Test func `homestead category progress aggregates built and total tiers`() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [
                .wheatField: 2,
                .chickenCoop: 1,
            ],
        )
        let farmingProgress = HomesteadCategoryProgress(category: .farming, homestead: homestead)
        #expect(farmingProgress.builtTiers == 3)
        #expect(farmingProgress.totalTiers > 3)
        #expect(farmingProgress.subtitle == "3 / \(farmingProgress.totalTiers)")
    }

    @Test func `labyrinth sizing grows narrow floors and contains selected edges`() {
        for width: CGFloat in [280, 360, 430] {
            let baseline = width / (3 * CGFloat(3).squareRoot())
            let narrow = LabyrinthMapPresentation.hexRadius(
                forAvailableWidth: width, projectedHalfColumnSpan: 2,
            )
            #expect(abs(narrow - baseline * LabyrinthMapPresentation.mapTargetScale) < 0.001)
            for span in 0 ... LabyrinthMapLayout.maxProjectedSpan {
                let radius = LabyrinthMapPresentation.hexRadius(
                    forAvailableWidth: width, projectedHalfColumnSpan: span,
                )
                let selectedWidth = radius * CGFloat(3).squareRoot() * (CGFloat(span) / 2 + 1.035) + 3
                // Viewport is the content width plus both 20pt content margins.
                #expect(selectedWidth <= width + 40 - LabyrinthMapPresentation.mapViewportGap + 0.001)
                if span == LabyrinthMapLayout.maxProjectedSpan {
                    // Three side-by-side hexes nearly touch the viewport edges.
                    let viewport = width + 40
                    let unselectedWidth = radius * CGFloat(3).squareRoot() * (CGFloat(span) / 2 + 1)
                    #expect(viewport - unselectedWidth >= LabyrinthMapPresentation.mapViewportGap)
                    #expect(viewport - unselectedWidth < 20)
                }
            }
        }
    }

    @Test func `labyrinth floor layout centers nodes and contains selected seals`() throws {
        let positions = [
            LabyrinthGridPosition(row: 0, column: -1),
            LabyrinthGridPosition(row: 1, column: -1),
            LabyrinthGridPosition(row: 2, column: 0),
        ]
        let nodes = positions.enumerated().map { index, position in
            LabyrinthNode(
                id: "node-\(index)", type: .battle, depth: 1,
                clusterID: "floor", gridPosition: position,
            )
        }

        for width: CGFloat in [280, 360, 430] {
            let layout = LabyrinthFloorLayout(nodes: nodes, availableWidth: width)
            let points = positions.map { layout.point(for: $0) }
            let left = try #require(points.map(\.x).min())
            let right = try #require(points.map(\.x).max())
            #expect(abs((left + right) / 2 - width / 2) < 0.001)
            let selectedHalfWidth = layout.hexWidth * 1.035 / 2 + 1.5
            // Selected seals may bleed into the 20pt content margins but must
            // stay 3pt inside the viewport edges (viewport = width + 40).
            let viewportInset = 20 - LabyrinthMapPresentation.mapViewportGap / 2
            #expect(left - selectedHalfWidth >= -viewportInset - 0.001)
            #expect(right + selectedHalfWidth <= width + viewportInset + 0.001)
            let lastPoint = try #require(points.last)
            #expect(abs(layout.height - (lastPoint.y + layout.hexHeight / 2 + layout.hitExpansion)) < 0.001)
        }
    }

    @Test func `homestead effect line display formatting`() {
        let tier = HomesteadNodeTier(
            tier: 1,
            stageName: "T1",
            cost: [],
            bonus: .init(title: "Bonus", description: "Desc"),
            combatBonus: .init(
                heroModifiers: [
                    .maximumHealth(10),
                    .damageTakenPercent(.physical, 0.15),
                ],
                astralChanceBonusPercent: 5,
                goldFindPercent: 10,
            ),
            production: [.init(.wood, 25)],
        )
        let lines = HomesteadEffectLine.lines(for: tier)
        let healthLine = lines.first(where: { $0.label == "Hero Health" })
        #expect(healthLine?.displayValue == "+10")

        let damageTakenLine = lines.first(where: { $0.label == "Physical damage taken" })
        #expect(damageTakenLine?.displayValue == "−15%")

        let astralLine = lines.first(where: { $0.id == .astralFind })
        #expect(astralLine?.displayValue == "+5%")

        let productionLine = lines.first(where: { $0.id == .production(.wood) })
        #expect(productionLine?.displayValue == "+25")
    }

    @Test func `labyrinth floor nodes sorts using grid positions and fallbacks`() {
        let nodeA = LabyrinthNode(
            id: "node-a",
            type: .battle,
            depth: 1,
            clusterID: "cluster-1",
            gridPosition: LabyrinthGridPosition(row: 1, column: 0),
        )
        let nodeB = LabyrinthNode(
            id: "node-b",
            type: .shop,
            depth: 1,
            clusterID: "cluster-1",
            gridPosition: nil,
        )
        let nodeC = LabyrinthNode(
            id: "node-c",
            type: .mystery,
            depth: 1,
            clusterID: "cluster-1",
            gridPosition: LabyrinthGridPosition(row: 0, column: 2),
        )
        let cluster = LabyrinthCluster(
            id: "cluster-1",
            depthBand: 1,
            nodeIDs: ["node-a", "node-b", "node-c"],
        )
        let state = PlayerLabyrinthState(nodes: ["node-a": nodeA, "node-b": nodeB, "node-c": nodeC])

        let sortedNodes: [LabyrinthNode] = LabyrinthMapPresentation.floorNodes(for: cluster, in: state)
        // Node B falls back to (row 0, column 0), node C is at (0, 2), node A is at (1, 0)
        #expect(sortedNodes.map(\.id) == ["node-b", "node-c", "node-a"])
    }

    @Test func `frame pacing report round trip and duration properties`() {
        let report = FramePacingReport(
            captureStartedAt: 100.0,
            captureEndedAt: 102.0,
            completionStatus: "completed",
            measurementDuration: 2.0,
            sampleCount: 120,
            expectedFPS: 60.0,
            averageFPS: 59.8,
            p95FrameMs: 16.9,
            p99FrameMs: 17.5,
            onePercentLowFPS: 55.0,
            maxFrameMs: 18.2,
            missedDeadlineCount: 1,
            estimatedMissedFrameCount: 1,
            severeStallCount: 0,
            missedDeadlineRatio: 1.0 / 120.0,
        )
        #expect(abs(report.sampledDuration - (120.0 / 59.8)) < 0.001)

        let encoded = report.accessibilityValue
        let parsed = FramePacingReport.parseAccessibilityValue(encoded)
        #expect(parsed == report)

        let emptyParsed = FramePacingReport.parseAccessibilityValue("invalid;format")
        #expect(emptyParsed == nil)

        let zeroReport = FramePacingReport.empty
        #expect(zeroReport.sampledDuration == 0)
    }
}
