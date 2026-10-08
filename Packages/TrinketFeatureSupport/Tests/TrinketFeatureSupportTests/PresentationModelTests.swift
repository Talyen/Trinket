import CoreGraphics
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketFeatureAdapters
@testable import TrinketFeatureSupport
@testable import TrinketPersistence

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
        let commands: [CombatantLoadoutEdit] = [.selectAbility(.slash), .equipItem(item, .weapon), .unequipItem(.weapon), .resetTalents]
        for command in commands {
            let before = playerSave.roster
            playerSave.forcesNextSaveFailure = true
            #expect(!playerSave.editCombatant(command, for: hero))
            #expect(playerSave.roster == before)
            #expect(playerSave.editCombatant(command, for: hero))
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
}
