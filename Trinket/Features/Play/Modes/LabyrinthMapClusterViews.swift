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
            radius: LabyrinthMapPresentation.hexRadius(forAvailableWidth: availableWidth),
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
                    unlockedCompanionIDs: roster.unlockedCompanionIDs,
                ),
                position: point(
                    for: node,
                    horizontalCenter: horizontalCenter,
                    metrics: metrics,
                ),
                renderPriority: node.id == selectedNodeID ? 2 : visualState == .reachable ? 1 : 0,
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
                    },
                )
                .position(presentation.position)
            }
        }
        .frame(width: availableWidth, height: mapHeight)
    }

    private func projectedX(
        for node: LabyrinthNode,
        metrics: LabyrinthHexMetrics,
    ) -> CGFloat {
        let position = node.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        return metrics.radius * sqrt(3) * (
            CGFloat(position.column) + CGFloat(position.row) / 2
        )
    }

    private func point(
        for node: LabyrinthNode,
        horizontalCenter: CGFloat,
        metrics: LabyrinthHexMetrics,
    ) -> CGPoint {
        let position = node.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        return CGPoint(
            x: availableWidth / 2 + (
                projectedX(for: node, metrics: metrics) - horizontalCenter
            ),
            y: CGFloat(position.row) * metrics.verticalStep + metrics.height / 2 + metrics.hitExpansion,
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
    @State private var clearedSettleScale: CGFloat = 1
    @State private var clearedSettleTask: Task<Void, Never>?

    private var tint: Color {
        LabyrinthMapPresentation.tint(for: type)
    }

    var body: some View {
        Button(action: onActivate) {
            ZStack {
                ZStack {
                    LabyrinthNodeArtwork(
                        node: node,
                        type: type,
                        resolvedMysteryEvent: resolvedMysteryEvent,
                        style: .hexSeal,
                    )
                    .saturation(visualState == .cleared ? 0 : 1)
                    .opacity(visualState == .locked ? 0.42 : visualState == .cleared ? 0.72 : 1)
                    if visualState == .cleared {
                        TrinketDesign.Colors.Overlay.ink.opacity(0.32)
                    }
                }
                .clipShape(LabyrinthHexagon())
                .scaleEffect(visualState == .cleared ? 0.97 : 1)

                LabyrinthHexagon()
                    .stroke(
                        isSelected ? TrinketDesign.Colors.accent :
                            visualState == .cleared ? TrinketDesign.Colors.subtleStroke.opacity(0.55) :
                            visualState == .locked ? TrinketDesign.Colors.subtleStroke : tint,
                        lineWidth: visualState == .cleared ? 1.5 : visualState == .reachable ? 3 : 2,
                    )

                LabyrinthHexagon()
                    .stroke(TrinketDesign.Colors.accent, lineWidth: 3)
                    .opacity(reachablePulseOpacity)
            }
            .frame(width: metrics.width, height: metrics.height)
            .scaleEffect(clearedSettleScale)
            .contentShape(
                .interaction,
                LabyrinthHexagon().inset(by: -metrics.hitExpansion),
            )
            .frame(
                width: metrics.width + 2 * metrics.hitExpansion,
                height: metrics.height + 2 * metrics.hitExpansion,
            )
        }
        .buttonStyle(LabyrinthNodeButtonStyle(isSelected: isSelected))
        .animation(TrinketMotion.Interaction.selection, value: visualState)
        .onChange(of: visualState) { oldState, newState in
            if oldState != .reachable, newState == .reachable {
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
            if oldState != .cleared, newState == .cleared {
                clearedSettleTask?.cancel()
                clearedSettleScale = 1
                clearedSettleTask = Task { @MainActor in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                        clearedSettleScale = 1.08
                    }
                    try? await Task.sleep(for: .milliseconds(95))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 1)) {
                        clearedSettleScale = 1
                    }
                }
            }
        }
        .onDisappear {
            reachablePulseTask?.cancel()
            clearedSettleTask?.cancel()
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
}

private struct LabyrinthNodeButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed ? 0.97 : (isSelected ? 1.035 : 1),
            )
            .offset(y: isSelected && !configuration.isPressed ? -2 : 0)
            .shadow(
                color: TrinketDesign.Colors.Overlay.dragShadow.opacity(isSelected ? 1 : 0),
                radius: isSelected ? 8 : 0,
                y: isSelected ? 5 : 0,
            )
            .animation(LabyrinthMapMotion.selection, value: configuration.isPressed)
            .animation(LabyrinthMapMotion.selection, value: isSelected)
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
            recruitEventID: node.recruitEventID,
        )
    }

    var body: some View {
        switch style {
        case .inspector:
            resolvedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .hexSeal:
            hexSealContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                variant: prefersThumbnail ? .card : .battle,
            )
        } else if type.canonical == .recruit,
                  let art = LabyrinthMapPresentation.recruitEncounterArtReference(
                      for: node,
                      worldSeed: playerSave.worldSeed,
                      unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
                      unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs,
                  ) {
            Image.preparedAsset(
                art,
                displaySize: prefersThumbnail ? .compact : .full,
            )
            .resizable()
            .scaledToFill()
            .decorativePreparedArtwork()
        } else if let event = resolvedMysteryEvent, !event.isRecruit {
            MysteryEventHeroArtwork(
                event: event,
                chapterID: "labyrinth",
                preferThumbnail: prefersThumbnail,
            )
        } else if let artID = LabyrinthMapPresentation.destinationEncounterArtID(for: type),
                  let art = ArtCatalog.encounterArtByID[artID] {
            Image.preparedAsset(
                art,
                displaySize: prefersThumbnail ? .compact : .full,
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

    @ViewBuilder
    private var hexSealContent: some View {
        if type.isCombat,
           let enemyID = node.enemyID,
           let enemy = GameContent.enemy(matching: enemyID),
           let art = enemy.combatant.artReference {
            combatFocal(art)
        } else if type.canonical == .recruit,
                  let art = LabyrinthMapPresentation.recruitEncounterArtReference(
                      for: node,
                      worldSeed: playerSave.worldSeed,
                      unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
                      unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs,
                  ) {
            encounterFocal(imageName: art.imageName, thumbnailName: art.thumbnailImageName, focalPoint: ArtFocalPoint(x: 0.5, y: 0.5))
        } else if let event = resolvedMysteryEvent, !event.isRecruit {
            hexMysteryFocalContent(for: event)
        } else if let artID = LabyrinthMapPresentation.destinationEncounterArtID(for: type),
                  let art = ArtCatalog.encounterArtByID[artID] {
            encounterFocal(imageName: art.imageName, thumbnailName: art.thumbnailImageName, focalPoint: ArtFocalPoint(x: 0.5, y: 0.5))
        } else {
            fallbackSymbol
        }
    }

    @ViewBuilder
    private func hexMysteryFocalContent(for event: MysteryEvent) -> some View {
        if let artID = event.artID, let art = ArtCatalog.encounterArtByID[artID] {
            encounterFocal(imageName: art.imageName, thumbnailName: art.thumbnailImageName, focalPoint: ArtFocalPoint(x: 0.5, y: 0.5))
        } else if let artID = event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
            encounterFocal(imageName: art.imageName, thumbnailName: art.thumbnailImageName, focalPoint: art.focalPoint)
        } else if let art = ArtCatalog.backgroundArtByID["labyrinth"] {
            encounterFocal(imageName: art.imageName, thumbnailName: art.thumbnailImageName, focalPoint: art.focalPoint)
        } else {
            fallbackSymbol
        }
    }

    private func combatFocal(_ art: CombatantArtReference) -> some View {
        LabyrinthFocalImage(
            imageName: art.imageName,
            thumbnailName: art.thumbnailImageName,
            focalPoint: art.focalPoint,
            displaySize: .compact,
            sourceAspect: LabyrinthNodeArtworkMetrics.combatSourceAspect,
            zoom: LabyrinthNodeArtworkMetrics.hexFocalZoom,
        )
    }

    private func encounterFocal(imageName: String, thumbnailName: String?, focalPoint: ArtFocalPoint) -> some View {
        LabyrinthFocalImage(
            imageName: imageName,
            thumbnailName: thumbnailName,
            focalPoint: focalPoint,
            displaySize: .compact,
            sourceAspect: LabyrinthNodeArtworkMetrics.encounterSourceAspect,
            zoom: LabyrinthNodeArtworkMetrics.hexFocalZoom,
        )
    }

    private var fallbackSymbol: some View {
        ZStack {
            LabyrinthMapPresentation.tint(for: type).opacity(0.16)
            Image(systemName: symbolName)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(LabyrinthMapPresentation.tint(for: type))
                .symbolRenderingMode(.hierarchical)
        }
    }
}
