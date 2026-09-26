import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct LabyrinthFloorMap: View {
    let cluster: LabyrinthCluster
    let snapshot: LabyrinthMapSnapshot

    private var state: PlayerLabyrinthState {
        snapshot.state
    }

    let selectedNodeID: String?
    let availableWidth: CGFloat
    let onSelectNode: (String) -> Void
    let onDismissSelection: () -> Void

    private var nodes: [LabyrinthNode] {
        LabyrinthMapPresentation.floorNodes(for: cluster, in: state)
    }

    var body: some View {
        let nodes = nodes
        let layout = LabyrinthFloorLayout(nodes: nodes, availableWidth: availableWidth)
        let reachableNodeIDs = state.reachableNodeIDSet()

        ZStack {
            Button(action: onDismissSelection) {
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss selection")
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthDismissSelection)

            ForEach(nodes) { node in
                let visualState = LabyrinthMapPresentation.state(for: node, reachableNodeIDs: reachableNodeIDs)
                let type = snapshot.type(for: node)
                LabyrinthMapNodeSeal(
                    node: node,
                    visualState: visualState,
                    type: type,
                    isSelected: selectedNodeID == node.id,
                    layout: layout,
                    resolvedMysteryEvent: snapshot.events[node.id],
                    recruitArtwork: snapshot.recruitArtwork(for: node),
                    floorDepthBand: cluster.depthBand,
                    onActivate: {
                        if visualState == .reachable {
                            onSelectNode(node.id)
                        }
                    },
                )
                .position(layout.point(for: node.gridPosition))
                .zIndex(Double(node.id == selectedNodeID ? 2 : visualState == .reachable ? 1 : 0))
            }
        }
        .frame(width: availableWidth, height: layout.height)
    }
}

private struct LabyrinthMapNodeSeal: View {
    let node: LabyrinthNode
    let visualState: LabyrinthMapNodeState
    let type: LabyrinthNodeType
    let isSelected: Bool
    let layout: LabyrinthFloorLayout
    let resolvedMysteryEvent: MysteryEvent?
    let recruitArtwork: EncounterArtReference?
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
                        recruitArtwork: recruitArtwork,
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
                        lineWidth: isSelected ? 3 : visualState == .cleared ? 1 : visualState == .reachable ? 2 : 1.5,
                    )

                LabyrinthHexagon()
                    .stroke(TrinketDesign.Colors.accent, lineWidth: 3)
                    .opacity(reachablePulseOpacity)
            }
            .frame(width: layout.hexWidth, height: layout.hexHeight)
            .scaleEffect(clearedSettleScale)
            .contentShape(
                .interaction,
                LabyrinthHexagon().inset(by: -layout.hitExpansion),
            )
            .frame(
                width: layout.hexWidth + 2 * layout.hitExpansion,
                height: layout.hexHeight + 2 * layout.hitExpansion,
            )
        }
        .buttonStyle(LabyrinthNodeButtonStyle(isSelected: isSelected))
        .disabled(visualState != .reachable)
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
        .accessibilityHint(visualState == .reachable ? "Shows node details" : "Not reachable")
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

    let node: LabyrinthNode
    let type: LabyrinthNodeType
    let resolvedMysteryEvent: MysteryEvent?
    let recruitArtwork: EncounterArtReference?
    var style: Style = .inspector

    private var icon: GameIcon {
        LabyrinthMapPresentation.icon(
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

    /// Single source for artwork selection: both the inspector and the hex
    /// seal resolve the same combat/recruit/mystery/destination precedence.
    /// Styles differ only in rendering (full artwork vs focal crop).
    private var combatEnemy: Enemy? {
        guard type.isCombat, let enemyID = node.enemyID else { return nil }
        return GameContent.enemy(matching: enemyID)
    }

    private var effectiveMysteryEvent: MysteryEvent? {
        guard let event = resolvedMysteryEvent, !event.isRecruit else { return nil }
        return event
    }

    private var destinationArt: EncounterArtReference? {
        guard let artID = LabyrinthMapPresentation.destinationEncounterArtID(for: type) else { return nil }
        return ArtCatalog.encounterArtByID[artID]
    }

    @ViewBuilder
    private var resolvedContent: some View {
        if let enemy = combatEnemy {
            CombatantArtwork(
                combatant: enemy.combatant,
                variant: prefersThumbnail ? .card : .battle,
            )
        } else if type == .recruit,
                  let art = recruitArtwork {
            MapTileArtwork(art: art, prefersThumbnail: prefersThumbnail)
        } else if let event = effectiveMysteryEvent {
            MysteryEventHeroArtwork(
                event: event,
                chapterID: EncounterArtIDs.labyrinthChapterID,
                prefersThumbnail: prefersThumbnail,
            )
        } else if let art = destinationArt {
            MapTileArtwork(art: art, prefersThumbnail: prefersThumbnail)
        } else {
            fallbackSymbol
        }
    }

    @ViewBuilder
    private var hexSealContent: some View {
        if let art = combatEnemy?.combatant.artReference {
            LabyrinthFocalImage(
                imageName: art.imageName,
                thumbnailName: art.thumbnailImageName,
                focalPoint: art.focalPoint,
                displaySize: .compact,
                zoom: LabyrinthNodeArtworkMetrics.hexFocalZoom,
            )
        } else if type == .recruit,
                  let art = recruitArtwork {
            LabyrinthFocalImage(
                imageName: art.imageName,
                thumbnailName: art.thumbnailImageName,
                focalPoint: ArtFocalPoint(x: 0.5, y: 0.5),
                displaySize: .compact,
                zoom: LabyrinthNodeArtworkMetrics.hexFocalZoom,
            )
        } else if let event = effectiveMysteryEvent {
            if let resolved = MysteryEventArtwork.focalContent(event: event, chapterID: EncounterArtIDs.labyrinthChapterID) {
                LabyrinthFocalImage(
                    imageName: resolved.imageName,
                    thumbnailName: resolved.thumbnailName,
                    focalPoint: resolved.focalPoint,
                    displaySize: .compact,
                    zoom: LabyrinthNodeArtworkMetrics.hexFocalZoom,
                )
            } else {
                fallbackSymbol
            }
        } else if let art = destinationArt {
            LabyrinthFocalImage(
                imageName: art.imageName,
                thumbnailName: art.thumbnailImageName,
                focalPoint: ArtFocalPoint(x: 0.5, y: 0.5),
                displaySize: .compact,
                zoom: LabyrinthNodeArtworkMetrics.hexFocalZoom,
            )
        } else {
            fallbackSymbol
        }
    }

    private var fallbackSymbol: some View {
        ZStack {
            LabyrinthMapPresentation.tint(for: type).opacity(0.16)
            GameIconImage(icon)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(LabyrinthMapPresentation.tint(for: type))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}

enum LabyrinthMapMotion {
    static var selection: Animation {
        .spring(response: 0.22, dampingFraction: 1)
    }

    static var inspector: Animation {
        .spring(response: 0.32, dampingFraction: 0.9)
    }

    static var floorChange: Animation {
        .spring(response: 0.38, dampingFraction: 1)
    }
}
