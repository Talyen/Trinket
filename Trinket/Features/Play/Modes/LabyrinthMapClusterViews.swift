import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

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
    @Environment(PlayerSaveStore.self) private var playerSave

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
            unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
            unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs
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
        case .locked, .reachable:
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

    func inset(by amount: CGFloat) -> Self {
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
    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(BattleSession.self) private var battle
    @Environment(PlayerSaveStore.self) private var playerSave

    let node: LabyrinthNode
    let state: PlayerLabyrinthState
    let onMessage: (StageMapMessage) -> Void

    private var type: LabyrinthNodeType {
        LabyrinthMapPresentation.effectiveType(
            for: node,
            unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
            unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs
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
            isPrimaryActionDisabled: battle.lifecyclePhase == .active,
            onArtworkTap: {
                if let enemyDetail {
                    battle.presentCombatantDetail(enemyDetail)
                }
            },
            onPrimaryAction: {
                if let message = labyrinth.handleNodeAction(nodeID: node.id) {
                    onMessage(message)
                }
            },
            artwork: {
                LabyrinthNodeArtwork(
                    node: node,
                    type: type,
                    pickContext: MysteryEventPickContext.labyrinth(
                        inventory: playerSave.inventory,
                        corruptionAltarCooldownRemaining: playerSave.currentSave
                            .corruptionAltarCooldownRemaining
                    )
                )
            },
            partyPickerSheet: {
                StageBattlePartyPickerSheet()
            },
            artworkAccessory: {
                modifierArtworkCaption
            }
        )
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNodeInspector)
    }

    private var subjectTitle: String {
        guard type.isCombat,
              let enemyID = node.enemyID,
              let enemy = GameContent.enemy(matching: enemyID)
        else { return type.title }
        return enemy.combatant.name
    }

    private var enemyDetail: CombatantCardDetail? {
        guard let encounter = labyrinth.resolvedEncounter(for: node) else {
            return nil
        }
        return CombatantCardDetail(
            combatant: encounter.combatant,
            inventoryItems: playerSave.inventory.items
        )
    }

    private var modifiers: [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers(ids: node.modifierIDs)
    }

    @ViewBuilder
    private var modifierArtworkCaption: some View {
        if !modifiers.isEmpty {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(modifiers) { modifier in
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                        HStack(spacing: TrinketDesign.Metrics.denseSpacing) {
                            Image(systemName: modifierSymbolName(for: modifier))
                                .symbolRenderingMode(.hierarchical)
                            Text(modifier.title.uppercased())
                        }
                        .trinketTypography(.eyebrow)
                        .trinketOnArtText(.title)

                        Text(modifier.effect.description)
                            .trinketTypography(.footnote)
                            .trinketOnArtText(.eyebrow)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
            .padding(.top, TrinketDesign.Metrics.extraLargeSpacing)
            .padding(.bottom, TrinketDesign.Metrics.mediumSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [
                        .clear,
                        TrinketDesign.Colors.Overlay.ink.opacity(0.82),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
        }
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
}

private struct LabyrinthNodeArtwork: View {
    let node: LabyrinthNode
    let type: LabyrinthNodeType
    let pickContext: MysteryEventPickContext

    private var symbolName: String {
        LabyrinthMapPresentation.symbolName(
            for: type,
            recruitEventID: node.recruitEventID
        )
    }

    private var resolvedMysteryEvent: MysteryEvent? {
        switch type.canonical {
        case .mystery, .event:
            GameContent.resolveLabyrinthMysteryEvent(
                nodeID: node.id,
                forcedEventID: nil,
                pinnedEventID: node.mysteryEventID,
                context: pickContext
            )
        default:
            nil
        }
    }

    var body: some View {
        Group {
            if type.isCombat,
               let enemyID = node.enemyID,
               let enemy = GameContent.enemy(matching: enemyID) {
                CombatantArtwork(combatant: enemy.combatant, variant: .battle)
            } else if let event = resolvedMysteryEvent, !event.isRecruit {
                MysteryEventHeroArtwork(event: event, chapterID: "labyrinth")
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
