import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

enum LabyrinthMapNodeState: Equatable {
    case locked
    case reachable
    case cleared
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

    static func actionTitle(for _: LabyrinthNode, type: LabyrinthNodeType) -> String {
        switch type.canonical {
        case .battle: "Battle"
        case .boss: "Challenge Boss"
        case .shop: "Visit Shop"
        case .rest: "Rest at Shrine"
        case .mystery, .event: "Approach Mystery"
        case .recruit: "Recruit"
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

    static func symbolName(for type: LabyrinthNodeType, recruitEventID: String?) -> String {
        if type.canonical == .recruit {
            return GameContent.recruitEncounterSymbolName(forEventID: recruitEventID)
        }
        return type.symbolName
    }
}

struct LabyrinthFloorMap: View {
    private static let maximumMapScale: CGFloat = 2
    private static let nodeFrame: CGFloat = 97
    private static let verticalStep = LabyrinthHexMetrics.radius * 1.5

    let cluster: LabyrinthCluster
    let state: PlayerLabyrinthState
    let selectedNodeID: String?
    let availableWidth: CGFloat
    let onSelectNode: (String) -> Void
    let onDismissSelection: () -> Void

    private var nodes: [LabyrinthNode] {
        LabyrinthMapPresentation.floorNodes(for: cluster, in: state)
    }

    private var mapHeight: CGFloat {
        let lastRow = nodes.compactMap(\.gridPosition?.row).max() ?? 0
        return (CGFloat(lastRow) * Self.verticalStep + 104) * mapScale
    }

    private var unscaledMapWidth: CGFloat {
        let projectedXs = nodes.map { projectedX(for: $0) }
        return (projectedXs.max() ?? 0) - (projectedXs.min() ?? 0) + Self.nodeFrame
    }

    private var mapScale: CGFloat {
        min(Self.maximumMapScale, availableWidth / max(1, unscaledMapWidth))
    }

    private var displayNodes: [LabyrinthNode] {
        nodes.sorted {
            renderPriority(for: $0) < renderPriority(for: $1)
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismissSelection)

            ForEach(displayNodes) { node in
                LabyrinthMapNodeSeal(
                    node: node,
                    state: state,
                    isSelected: selectedNodeID == node.id,
                    scale: mapScale,
                    onActivate: {
                        if LabyrinthMapPresentation.state(for: node, in: state) == .reachable {
                            onSelectNode(node.id)
                        } else {
                            onDismissSelection()
                        }
                    }
                )
                .position(point(for: node))
            }
        }
        .frame(width: availableWidth, height: mapHeight)
    }

    private func projectedX(for node: LabyrinthNode) -> CGFloat {
        let position = node.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        return LabyrinthHexMetrics.radius * sqrt(3) * (
            CGFloat(position.column) + CGFloat(position.row) / 2
        )
    }

    private func renderPriority(for node: LabyrinthNode) -> Int {
        if node.id == selectedNodeID {
            return 2
        }
        return LabyrinthMapPresentation.state(for: node, in: state) == .reachable ? 1 : 0
    }

    private func point(for node: LabyrinthNode) -> CGPoint {
        let position = node.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        let projectedXs = nodes.map { projectedX(for: $0) }
        let horizontalCenter = ((projectedXs.min() ?? 0) + (projectedXs.max() ?? 0)) / 2
        return CGPoint(
            x: availableWidth / 2 + (projectedX(for: node) - horizontalCenter) * mapScale,
            y: (CGFloat(position.row) * Self.verticalStep + 52) * mapScale
        )
    }
}

private struct LabyrinthMapNodeSeal: View {
    @Environment(AppState.self) private var appState

    let node: LabyrinthNode
    let state: PlayerLabyrinthState
    let isSelected: Bool
    let scale: CGFloat
    let onActivate: () -> Void

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

    private var displayedTint: Color {
        visualState == .cleared ? TrinketDesign.Colors.success.opacity(0.55) : tint
    }

    var body: some View {
        Button(action: onActivate) {
            ZStack {
                LabyrinthHexagon()
                    .stroke(
                        visualState == .cleared
                            ? displayedTint
                            : isSelected
                            ? TrinketDesign.Colors.accent
                            : visualState == .locked
                            ? TrinketDesign.Colors.subtleStroke
                            : displayedTint,
                        lineWidth: visualState == .reachable ? 3 : 2
                    )
                Image(systemName: symbolName)
                    .trinketTypography(type == .boss ? .sectionTitle : .rowTitle)
                    .foregroundStyle(
                        visualState == .locked
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(displayedTint)
                    )
            }
            .frame(width: LabyrinthHexMetrics.width, height: LabyrinthHexMetrics.height)
            .contentShape(
                .interaction,
                LabyrinthHexagon().inset(by: -LabyrinthHexMetrics.hitExpansion)
            )
            .scaleEffect(scale)
            .frame(
                width: (LabyrinthHexMetrics.width + 2 * LabyrinthHexMetrics.hitExpansion) * scale,
                height: (LabyrinthHexMetrics.height + 2 * LabyrinthHexMetrics.hitExpansion) * scale
            )
        }
        .buttonStyle(LabyrinthNodeButtonStyle(isSelected: isSelected))
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNode(node.id))
    }

    private var symbolName: String {
        if type == .boss {
            return type.symbolName
        }
        return switch visualState {
        case .locked:
            "lock.fill"
        case .reachable:
            LabyrinthMapPresentation.symbolName(
                for: type,
                recruitEventID: node.recruitEventID
            )
        case .cleared:
            "checkmark"
        }
    }
}

private enum LabyrinthHexMetrics {
    static let radius: CGFloat = 32
    static let width = radius * sqrt(3)
    static let height = radius * 2
    static let hitExpansion: CGFloat = 6
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
    @State private var selectedModifierID: LabyrinthModifierID?

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
            activeEyebrow: "Floor \(node.depth)",
            mapLabel: "Floor \(node.depth)",
            title: subjectTitle,
            activeDetailLines: [],
            encounterTypeTitle: type.title,
            symbolName: LabyrinthMapPresentation.symbolName(
                for: type,
                recruitEventID: node.recruitEventID
            ),
            tint: LabyrinthMapPresentation.tint(for: type),
            primaryActionTitle: LabyrinthMapPresentation.actionTitle(for: node, type: type),
            showsPartyPicker: type.isCombat,
            isArtworkInteractive: enemyDetail != nil,
            rowAccessibilityID: AccessibilityID.Play.labyrinthNode(node.id),
            artworkAccessibilityID: AccessibilityID.Play.labyrinthNodeArtwork(node.id),
            actionAccessibilityID: AccessibilityID.Play.labyrinthInspectorAction(node.id),
            activeDetailAccessibilityID: AccessibilityID.Play.labyrinthNodeInspector,
            partyControlAccessibilityID: "Labyrinth Node \(node.id) Party Control"
        )
    }

    var body: some View {
        StageSelectActiveCard(
            presentation: presentation,
            isPrimaryActionDisabled: appState.battle.activeBattle != nil,
            onArtworkTap: {
                if let enemyDetail {
                    appState.battle.presentCombatantDetail(enemyDetail)
                }
            },
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
            artworkAccessory: {
                modifierCornerTab
            }
        )
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNodeInspector)
        .onChange(of: node.id) { _, _ in
            selectedModifierID = nil
        }
    }

    private var subjectTitle: String {
        guard type.isCombat,
              let enemyID = node.enemyID,
              let enemy = GameContent.enemy(matching: enemyID)
        else { return type.title }
        return enemy.combatant.name
    }

    private var enemyDetail: CombatantCardDetail? {
        guard let encounter = ActiveBattleConfiguration.resolvedLabyrinthEncounter(for: node) else {
            return nil
        }
        return CombatantCardDetail(
            combatant: encounter.combatant,
            inventoryState: appState.inventory
        )
    }

    private var modifiers: [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers(ids: node.modifierIDs)
    }

    @ViewBuilder
    private var modifierCornerTab: some View {
        if !modifiers.isEmpty {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(modifiers) { modifier in
                    Button {
                        selectedModifierID = modifier.id
                    } label: {
                        Image(systemName: modifierSymbolName(for: modifier))
                            .symbolRenderingMode(.hierarchical)
                            .trinketTypography(.button)
                            .foregroundStyle(modifierTint(for: modifier))
                            // UIStyleCheck: allow - Bare modifier icon matching party picker size without chip chrome.
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .trinketQuietTapButtonStyle()
                    .accessibilityIdentifier(
                        AccessibilityID.Play.labyrinthModifier(modifier.id.rawValue)
                    )
                    .popover(
                        isPresented: Binding(
                            get: { selectedModifierID == modifier.id },
                            set: { isPresented in
                                if !isPresented, selectedModifierID == modifier.id {
                                    selectedModifierID = nil
                                }
                            }
                        )
                    ) {
                        modifierPopover(modifier)
                            .presentationCompactAdaptation(.popover)
                            .presentationSizing(.fitted)
                    }
                }
            }
            .background(
                TrinketDesign.Colors.elevated,
                in: RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
            )
        }
    }

    private func modifierPopover(_ modifier: LabyrinthModifierDefinition) -> some View {
        let tint = modifierTint(for: modifier)
        return VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Image(systemName: modifierSymbolName(for: modifier))
                    .foregroundStyle(tint)

                Text(modifier.title)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(tint)
            }

            Text(modifier.effect.description)
                .trinketTypography(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, TrinketDesign.Metrics.largeSpacing)
        .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        .frame(width: 280, alignment: .leading)
        .accessibilityIdentifier(
            AccessibilityID.Play.labyrinthModifierPopover(modifier.id.rawValue)
        )
    }

    private func modifierSymbolName(for modifier: LabyrinthModifierDefinition) -> String {
        switch modifier.id.rawValue {
        case "ironPressure": "burst.fill"
        case "ashTithe": "flame.fill"
        case "bloodMarket", "serpentBloom": "drop.fill"
        case "rimeTax": "snowflake"
        case "gildedWhisper": "circle.circle.fill"
        case "astralSeam": "sparkles"
        default: "sparkles"
        }
    }

    private func modifierTint(for modifier: LabyrinthModifierDefinition) -> Color {
        switch modifier.id.rawValue {
        case "ironPressure": Keyword.physical.visualStyle.color
        case "ashTithe": Keyword.burn.visualStyle.color
        case "bloodMarket": Keyword.bleed.visualStyle.color
        case "serpentBloom": Keyword.poison.visualStyle.color
        case "rimeTax": Keyword.freeze.visualStyle.color
        case "gildedWhisper": Keyword.gold.visualStyle.color
        case "astralSeam": TrinketDesign.Colors.arcane
        default: TrinketDesign.Colors.accent
        }
    }
}

private struct LabyrinthNodeArtwork: View {
    let node: LabyrinthNode
    let type: LabyrinthNodeType

    private var symbolName: String {
        LabyrinthMapPresentation.symbolName(
            for: type,
            recruitEventID: node.recruitEventID
        )
    }

    var body: some View {
        Group {
            if type.isCombat,
               let enemyID = node.enemyID,
               let enemy = GameContent.enemy(matching: enemyID) {
                CombatantArtwork(combatant: enemy.combatant, variant: .battle)
            } else {
                ZStack {
                    LabyrinthMapPresentation.tint(for: type).opacity(0.16)
                    Image(systemName: symbolName)
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
