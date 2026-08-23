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
    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(PlayerSaveStore.self) private var playerSave

    let cluster: LabyrinthCluster
    let state: PlayerLabyrinthState
    let selectedNodeID: String?
    let availableWidth: CGFloat
    let onSelectNode: (String) -> Void
    let onDismissSelection: () -> Void

    private var metrics: LabyrinthHexMetrics {
        LabyrinthHexMetrics(
            radius: LabyrinthMapPresentation.hexRadius(forAvailableWidth: availableWidth)
        )
    }

    private var nodes: [LabyrinthNode] {
        LabyrinthMapPresentation.floorNodes(for: cluster, in: state)
    }

    var body: some View {
        let metrics = metrics
        let nodes = nodes
        let projectedXs = nodes.map { projectedX(for: $0, metrics: metrics) }
        let horizontalCenter = ((projectedXs.min() ?? 0) + (projectedXs.max() ?? 0)) / 2
        let lastRow = nodes.compactMap(\.gridPosition?.row).max() ?? 0
        let mapHeight = CGFloat(lastRow) * metrics.verticalStep
            + metrics.height
            + metrics.hitExpansion * 2
        let roster = playerSave.roster
        let displayNodes = nodes.map { node in
            let visualState = LabyrinthMapPresentation.state(for: node, in: state)
            return LabyrinthMapNodePresentation(
                node: node,
                visualState: visualState,
                type: LabyrinthMapPresentation.effectiveType(
                    for: node,
                    worldSeed: playerSave.worldSeed,
                    unlockedHeroIDs: roster.unlockedHeroIDs,
                    unlockedCompanionIDs: roster.unlockedCompanionIDs
                ),
                position: point(
                    for: node,
                    horizontalCenter: horizontalCenter,
                    metrics: metrics
                ),
                renderPriority: node.id == selectedNodeID ? 2 : visualState == .reachable ? 1 : 0
            )
        }.sorted {
            $0.renderPriority < $1.renderPriority
        }

        ZStack {
            Button(action: onDismissSelection) {
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .trinketQuietTapButtonStyle()

            ForEach(displayNodes) { presentation in
                LabyrinthMapNodeSeal(
                    node: presentation.node,
                    visualState: presentation.visualState,
                    type: presentation.type,
                    isSelected: selectedNodeID == presentation.id,
                    metrics: metrics,
                    resolvedMysteryEvent: labyrinth.previewMysteryEvent(for: presentation.node),
                    floorDepthBand: cluster.depthBand,
                    onActivate: {
                        if presentation.visualState == .reachable {
                            onSelectNode(presentation.id)
                        } else {
                            onDismissSelection()
                        }
                    }
                )
                .position(presentation.position)
            }
        }
        .frame(width: availableWidth, height: mapHeight)
    }

    private func projectedX(
        for node: LabyrinthNode,
        metrics: LabyrinthHexMetrics
    ) -> CGFloat {
        let position = node.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        return metrics.radius * sqrt(3) * (
            CGFloat(position.column) + CGFloat(position.row) / 2
        )
    }

    private func point(
        for node: LabyrinthNode,
        horizontalCenter: CGFloat,
        metrics: LabyrinthHexMetrics
    ) -> CGPoint {
        let position = node.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        return CGPoint(
            x: availableWidth / 2 + (
                projectedX(for: node, metrics: metrics) - horizontalCenter
            ),
            y: CGFloat(position.row) * metrics.verticalStep + metrics.height / 2 + metrics.hitExpansion
        )
    }
}

private struct LabyrinthMapNodePresentation: Identifiable {
    let node: LabyrinthNode
    let visualState: LabyrinthMapNodeState
    let type: LabyrinthNodeType
    let position: CGPoint
    let renderPriority: Int

    var id: String {
        node.id
    }
}

private struct LabyrinthMapNodeSeal: View {
    let node: LabyrinthNode
    let visualState: LabyrinthMapNodeState
    let type: LabyrinthNodeType
    let isSelected: Bool
    let metrics: LabyrinthHexMetrics
    let resolvedMysteryEvent: MysteryEvent?
    let floorDepthBand: Int
    let onActivate: () -> Void
    @State private var reachablePulseOpacity: Double = 0
    @State private var reachablePulseTask: Task<Void, Never>?

    private var tint: Color {
        LabyrinthMapPresentation.tint(for: type)
    }

    private var displayedTint: Color {
        visualState == .cleared ? TrinketDesign.Colors.success.opacity(0.55) : tint
    }

    var body: some View {
        Button(action: onActivate) {
            ZStack {
                LabyrinthNodeArtwork(
                    node: node,
                    type: type,
                    resolvedMysteryEvent: resolvedMysteryEvent,
                    style: .hexSeal
                )
                .opacity(visualState == .locked ? 0.42 : 1)
                .clipShape(LabyrinthHexagon())

                if visualState == .cleared {
                    Image(systemName: "checkmark")
                        .trinketTypography(type == .boss ? .sectionTitle : .rowTitle)
                        .foregroundStyle(TrinketDesign.Colors.success)
                        .shadow(color: TrinketDesign.Colors.Overlay.ink.opacity(0.55), radius: 2, y: 1)
                        .transition(checkmarkTransition)
                }

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

                LabyrinthHexagon()
                    .stroke(TrinketDesign.Colors.accent, lineWidth: 3)
                    .opacity(reachablePulseOpacity)
            }
            .frame(width: metrics.width, height: metrics.height)
            .contentShape(
                .interaction,
                LabyrinthHexagon().inset(by: -metrics.hitExpansion)
            )
            .frame(
                width: metrics.width + 2 * metrics.hitExpansion,
                height: metrics.height + 2 * metrics.hitExpansion
            )
        }
        .buttonStyle(LabyrinthNodeButtonStyle(isSelected: isSelected))
        .animation(TrinketMotion.Interaction.selection, value: visualState)
        .onChange(of: visualState) { oldState, newState in
            guard oldState != .reachable, newState == .reachable else { return }
            reachablePulseTask?.cancel()
            reachablePulseOpacity = 0
            reachablePulseTask = Task { @MainActor in
                withAnimation(.easeOut(duration: 0.12)) {
                    reachablePulseOpacity = 0.72
                }
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.23)) {
                    reachablePulseOpacity = 0
                }
            }
        }
        .onDisappear {
            reachablePulseTask?.cancel()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nodeAccessibilityLabel)
        .accessibilityIdentifier(labyrinthAccessibilityIdentifier)
    }

    private var nodeAccessibilityLabel: String {
        switch visualState {
        case .cleared: "\(type.title), cleared"
        case .locked: "\(type.title), locked"
        case .reachable: type.title
        }
    }

    private var labyrinthAccessibilityIdentifier: String {
        guard floorDepthBand == 1 else {
            return AccessibilityID.Play.labyrinthNode(node.id)
        }
        if node.id.hasSuffix("-n0") {
            return AccessibilityID.Play.labyrinthFloor1EntryNode
        }
        if node.id.hasSuffix("-n2") {
            return AccessibilityID.Play.labyrinthFloor1LockedNode
        }
        return AccessibilityID.Play.labyrinthNode(node.id)
    }

    private var checkmarkTransition: AnyTransition {
        .scale(scale: 0.85).combined(with: .opacity)
    }
}

private struct LabyrinthHexMetrics {
    let radius: CGFloat
    let hitExpansion: CGFloat = 6

    var width: CGFloat {
        radius * sqrt(3)
    }

    var height: CGFloat {
        radius * 2
    }

    var verticalStep: CGFloat {
        radius * 1.5
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
            .scaleEffect(
                configuration.isPressed ? 0.97 : (isSelected ? 1.035 : 1)
            )
            .offset(y: isSelected && !configuration.isPressed ? -2 : 0)
            .shadow(
                color: TrinketDesign.Colors.Overlay.dragShadow.opacity(isSelected ? 1 : 0),
                radius: isSelected ? 8 : 0,
                y: isSelected ? 5 : 0
            )
            .animation(TrinketMotion.Labyrinth.selection, value: configuration.isPressed)
            .animation(TrinketMotion.Labyrinth.selection, value: isSelected)
    }
}

struct LabyrinthNodeArtwork: View {
    enum Style {
        case inspector
        case hexSeal
    }

    @Environment(PlayerSaveStore.self) private var playerSave

    let node: LabyrinthNode
    let type: LabyrinthNodeType
    let resolvedMysteryEvent: MysteryEvent?
    var style: Style = .inspector

    private var symbolName: String {
        LabyrinthMapPresentation.symbolName(
            for: type,
            recruitEventID: node.recruitEventID
        )
    }

    var body: some View {
        switch style {
        case .inspector:
            resolvedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .hexSeal:
            Color.clear
                .overlay(alignment: .top) {
                    resolvedContent
                        .scaledToFill()
                }
                .clipped()
        }
    }

    private var prefersThumbnail: Bool {
        style == .hexSeal
    }

    @ViewBuilder
    private var resolvedContent: some View {
        if type.isCombat,
           let enemyID = node.enemyID,
           let enemy = GameContent.enemy(matching: enemyID) {
            CombatantArtwork(
                combatant: enemy.combatant,
                variant: prefersThumbnail ? .card : .battle
            )
        } else if type.canonical == .recruit,
                  let art = LabyrinthMapPresentation.recruitEncounterArtReference(
                      for: node,
                      worldSeed: playerSave.worldSeed,
                      unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
                      unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs
                  ) {
            Image.preparedAsset(
                art,
                displaySize: prefersThumbnail ? .compact : .full
            )
            .resizable()
            .scaledToFill()
            .decorativePreparedArtwork()
        } else if let event = resolvedMysteryEvent, !event.isRecruit {
            MysteryEventHeroArtwork(
                event: event,
                chapterID: "labyrinth",
                preferThumbnail: prefersThumbnail
            )
        } else if let artID = LabyrinthMapPresentation.destinationEncounterArtID(for: type),
                  let art = ArtCatalog.encounterArtByID[artID] {
            Image.preparedAsset(
                art,
                displaySize: prefersThumbnail ? .compact : .full
            )
            .resizable()
            .scaledToFill()
            .decorativePreparedArtwork()
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
}
