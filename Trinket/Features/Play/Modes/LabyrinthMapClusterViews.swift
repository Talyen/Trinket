import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

enum LabyrinthMapNodeState: Equatable {
    case locked
    case reachable
    case cleared
}

enum LabyrinthConnectorState: Equatable {
    case locked
    case reachable
    case cleared
    case selected
}

enum LabyrinthMapPresentation {
    static func floorNodes(
        for cluster: LabyrinthCluster,
        in state: PlayerLabyrinthState
    ) -> [LabyrinthNode] {
        cluster.nodeIDs.compactMap { state.nodes[$0] }.sorted {
            let left = $0.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1)
            let right = $1.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1)
            return left.row == right.row ? left.column < right.column : left.row < right.row
        }
    }

    static func effectiveType(
        for node: LabyrinthNode,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> LabyrinthNodeType {
        guard node.type.canonical == .recruit else { return node.type.canonical }
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: node.recruitEventID,
            encounterID: node.id,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs
        )
        if case .mystery = resolution {
            return .mystery
        }
        return .recruit
    }

    static func state(for node: LabyrinthNode, in labyrinth: PlayerLabyrinthState) -> LabyrinthMapNodeState {
        if node.isCleared {
            return .cleared
        }
        return labyrinth.isNodeReachable(node.id) ? .reachable : .locked
    }

    static func connectorState(
        from source: LabyrinthNode,
        to target: LabyrinthNode,
        selectedNodeID: String?,
        in labyrinth: PlayerLabyrinthState
    ) -> LabyrinthConnectorState {
        if selectedNodeID == source.id || selectedNodeID == target.id {
            return .selected
        }
        if source.isCleared, target.isCleared {
            return .cleared
        }
        if source.isCleared || labyrinth.isNodeReachable(target.id) {
            return .reachable
        }
        return .locked
    }

    static func modifierDetailLines(_ modifier: LabyrinthModifierDefinition) -> [String] {
        [modifier.effect.description]
    }

    static func actionTitle(for _: LabyrinthNode, type: LabyrinthNodeType) -> String {
        switch type.canonical {
        case .battle: "Battle"
        case .boss: "Challenge Boss"
        case .shop: "Visit Shop"
        case .rest: "Rest at Shrine"
        case .mystery, .event: "Approach Mystery"
        case .recruit: "Meet Recruit"
        case .craft: "Use Crafting Altar"
        case .gate: "Descend"
        }
    }

    static func tint(for type: LabyrinthNodeType) -> Color {
        switch type.canonical {
        case .battle, .boss, .gate: TrinketDesign.Colors.encounterBattle
        case .shop: TrinketDesign.Colors.encounterShop
        case .rest: TrinketDesign.Colors.encounterRest
        case .mystery, .event, .recruit, .craft: TrinketDesign.Colors.encounterEvent
        }
    }
}

struct LabyrinthFloorMap: View {
    private static let hexRadius: CGFloat = 32
    private static let verticalStep = hexRadius * 1.5

    let cluster: LabyrinthCluster
    let state: PlayerLabyrinthState
    let selectedNodeID: String?
    let onSelectNode: (String) -> Void
    let onDismissSelection: () -> Void

    private var nodes: [LabyrinthNode] {
        LabyrinthMapPresentation.floorNodes(for: cluster, in: state)
    }

    private var mapHeight: CGFloat {
        let lastRow = nodes.compactMap(\.gridPosition?.row).max() ?? 0
        return CGFloat(lastRow) * Self.verticalStep + 104
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                connectorCanvas(size: proxy.size)

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismissSelection)

                ForEach(nodes) { node in
                    LabyrinthMapNodeSeal(
                        node: node,
                        state: state,
                        isSelected: selectedNodeID == node.id,
                        onSelect: { onSelectNode(node.id) }
                    )
                    .position(point(for: node, size: proxy.size))
                }
            }
        }
        .frame(height: mapHeight)
    }

    private func connectorCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            for source in nodes {
                for targetID in source.outgoingIDs {
                    guard let target = state.nodes[targetID], target.clusterID == cluster.id else { continue }
                    var path = Path()
                    let connectorState = LabyrinthMapPresentation.connectorState(
                        from: source,
                        to: target,
                        selectedNodeID: selectedNodeID,
                        in: state
                    )
                    let color = switch connectorState {
                    case .selected: TrinketDesign.Colors.accent
                    case .cleared: TrinketDesign.Colors.success
                    case .locked, .reachable: TrinketDesign.Colors.subtleStroke
                    }
                    let sourcePoint = point(for: source, size: size)
                    let targetPoint = point(for: target, size: size)
                    let delta = CGVector(
                        dx: targetPoint.x - sourcePoint.x,
                        dy: targetPoint.y - sourcePoint.y
                    )
                    let length = max(1, hypot(delta.dx, delta.dy))
                    let edgeInset = Self.hexRadius - 2
                    path.move(to: CGPoint(
                        x: sourcePoint.x + delta.dx / length * edgeInset,
                        y: sourcePoint.y + delta.dy / length * edgeInset
                    ))
                    path.addLine(to: CGPoint(
                        x: targetPoint.x - delta.dx / length * edgeInset,
                        y: targetPoint.y - delta.dy / length * edgeInset
                    ))
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(
                            lineWidth: connectorState == .selected ? 4 : 3,
                            lineCap: .round,
                            dash: connectorState == .locked ? [3, 3] : []
                        )
                    )
                }
            }
        }
        .animation(TrinketMotion.Labyrinth.pathState, value: state)
        .allowsHitTesting(false)
    }

    private func point(for node: LabyrinthNode, size: CGSize) -> CGPoint {
        let position = node.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        let rawX = Self.hexRadius * sqrt(3) * (
            CGFloat(position.column) + CGFloat(position.row) / 2
        )
        let projectedXs = nodes.map { candidate -> CGFloat in
            let candidatePosition = candidate.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
            return Self.hexRadius * sqrt(3) * (
                CGFloat(candidatePosition.column) + CGFloat(candidatePosition.row) / 2
            )
        }
        let horizontalCenter = ((projectedXs.min() ?? 0) + (projectedXs.max() ?? 0)) / 2
        return CGPoint(
            x: size.width / 2 + rawX - horizontalCenter,
            y: CGFloat(position.row) * Self.verticalStep + 52
        )
    }
}

private struct LabyrinthMapNodeSeal: View {
    @Environment(AppState.self) private var appState

    let node: LabyrinthNode
    let state: PlayerLabyrinthState
    let isSelected: Bool
    let onSelect: () -> Void

    private var visualState: LabyrinthMapNodeState {
        LabyrinthMapPresentation.state(for: node, in: state)
    }

    private var type: LabyrinthNodeType {
        LabyrinthMapPresentation.effectiveType(
            for: node,
            unlockedHeroIDs: appState.roster.unlockedHeroIDs,
            unlockedCompanionIDs: appState.roster.unlockedCompanionIDs
        )
    }

    private var tint: Color {
        LabyrinthMapPresentation.tint(for: type)
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                LabyrinthHexagon()
                    .strokeBorder(
                        visualState == .locked
                            ? TrinketDesign.Colors.subtleStroke
                            : tint,
                        lineWidth: visualState == .reachable ? 3 : 2
                    )
                if type == .boss {
                    LabyrinthHexagon()
                        .inset(by: 5)
                        .strokeBorder(
                            visualState == .locked ? TrinketDesign.Colors.subtleStroke : tint,
                            lineWidth: 1.5
                        )
                }
                if isSelected {
                    LabyrinthHexagon()
                        .inset(by: -4)
                        .strokeBorder(TrinketDesign.Colors.accent, lineWidth: 2)
                }
                Image(systemName: symbolName)
                    .trinketTypography(type == .boss ? .sectionTitle : .rowTitle)
                    .foregroundStyle(
                        visualState == .locked
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(tint)
                    )
            }
            .frame(width: 58, height: 66)
            .frame(width: 92, height: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(LabyrinthNodeButtonStyle(isSelected: isSelected))
        .disabled(visualState != .reachable)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNode(node.id))
    }

    private var symbolName: String {
        switch visualState {
        case .locked: "lock.fill"
        case .reachable: type.symbolName
        case .cleared: "checkmark"
        }
    }
}

private struct LabyrinthHexagon: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width / sqrt(3), rect.height / 2)
        var path = Path()
        for index in 0 ..< 6 {
            let angle = CGFloat(index) * .pi / 3 - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> LabyrinthHexagon {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

private struct LabyrinthNodeButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : (isSelected ? 1.05 : 1))
            .offset(y: isSelected && !configuration.isPressed ? -3 : 0)
            .shadow(
                color: TrinketDesign.Colors.Overlay.dragShadow.opacity(isSelected ? 1 : 0),
                radius: isSelected ? 8 : 0,
                y: isSelected ? 5 : 0
            )
            .animation(TrinketMotion.Labyrinth.selection, value: configuration.isPressed)
            .animation(TrinketMotion.Labyrinth.selection, value: isSelected)
    }
}

struct LabyrinthNodeInspector: View {
    @Environment(AppState.self) private var appState

    let node: LabyrinthNode
    let state: PlayerLabyrinthState
    let onMessage: (StageMapMessage) -> Void

    private var type: LabyrinthNodeType {
        LabyrinthMapPresentation.effectiveType(
            for: node,
            unlockedHeroIDs: appState.roster.unlockedHeroIDs,
            unlockedCompanionIDs: appState.roster.unlockedCompanionIDs
        )
    }

    private var presentation: StageSelectRowPresentation<LabyrinthNode> {
        StageSelectRowPresentation(
            item: node,
            isActive: true,
            activeEyebrow: "Floor \(node.depth) · \(type.title)",
            mapLabel: "Floor \(node.depth)",
            title: subjectTitle,
            activeDetailLines: detailLines,
            encounterTypeTitle: type.title,
            symbolName: type.symbolName,
            tint: LabyrinthMapPresentation.tint(for: type),
            primaryActionTitle: LabyrinthMapPresentation.actionTitle(for: node, type: type),
            showsPartyPicker: type.isCombat,
            isArtworkInteractive: false,
            rowAccessibilityID: AccessibilityID.Play.labyrinthNode(node.id),
            artworkAccessibilityID: "Labyrinth Node \(node.id) Artwork",
            actionAccessibilityID: AccessibilityID.Play.labyrinthInspectorAction(node.id),
            activeDetailAccessibilityID: AccessibilityID.Play.labyrinthNodeInspector,
            partyControlAccessibilityID: "Labyrinth Node \(node.id) Party Control"
        )
    }

    var body: some View {
        StageSelectActiveCard(
            presentation: presentation,
            isPrimaryActionDisabled: appState.battle.activeBattle != nil,
            onArtworkTap: {},
            onPrimaryAction: {
                if let message = appState.handleLabyrinthNodeAction(nodeID: node.id) {
                    onMessage(message)
                }
            },
            artwork: {
                LabyrinthNodeArtwork(node: node, type: type)
            },
            partyPickerSheet: {
                StageBattlePartyPickerSheet()
            },
            layout: .compact
        )
        .trinketMaterial(.popover)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNodeInspector)
    }

    private var subjectTitle: String {
        guard type.isCombat,
              let enemyID = node.enemyID,
              let enemy = GameContent.enemy(matching: enemyID)
        else { return type.title }
        return enemy.combatant.name
    }

    private var detailLines: [String] {
        guard let modifier = LabyrinthCatalog.modifiers(ids: node.modifierIDs).first else { return [] }
        return [modifier.title, modifier.effect.description]
    }
}

private struct LabyrinthNodeArtwork: View {
    let node: LabyrinthNode
    let type: LabyrinthNodeType

    var body: some View {
        Group {
            if type.isCombat,
               let enemyID = node.enemyID,
               let enemy = GameContent.enemy(matching: enemyID) {
                CombatantArtwork(combatant: enemy.combatant, variant: .battle)
            } else {
                ZStack {
                    LabyrinthMapPresentation.tint(for: type).opacity(0.16)
                    Image(systemName: type.symbolName)
                        .trinketTypography(.sectionDisplay)
                        .foregroundStyle(LabyrinthMapPresentation.tint(for: type))
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
