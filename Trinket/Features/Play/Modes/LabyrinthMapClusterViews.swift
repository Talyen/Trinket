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

    /// Built once for the floor so seals do not rematerialize inventory / save.
    private var pickContext: MysteryEventPickContext {
        MysteryEventPickContext.labyrinth(
            inventory: playerSave.inventory,
            corruptionAltarCooldownRemaining: playerSave.corruptionAltarCooldownRemaining
        )
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
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismissSelection)

            ForEach(displayNodes) { presentation in
                LabyrinthMapNodeSeal(
                    node: presentation.node,
                    visualState: presentation.visualState,
                    type: presentation.type,
                    isSelected: selectedNodeID == presentation.id,
                    metrics: metrics,
                    pickContext: pickContext,
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let node: LabyrinthNode
    let visualState: LabyrinthMapNodeState
    let type: LabyrinthNodeType
    let isSelected: Bool
    let metrics: LabyrinthHexMetrics
    let pickContext: MysteryEventPickContext
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
                    pickContext: pickContext,
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
            guard oldState != .reachable, newState == .reachable, !reduceMotion else { return }
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
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNode(node.id))
    }

    private var checkmarkTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion ? 1 : configuration.isPressed ? 0.97 : (isSelected ? 1.035 : 1)
            )
            .offset(y: reduceMotion ? 0 : isSelected && !configuration.isPressed ? -2 : 0)
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
            worldSeed: playerSave.worldSeed,
            unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
            unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs
        )
    }

    private var presentation: StageSelectRowPresentation<LabyrinthNode> {
        StageSelectRowPresentation.labyrinthRow(
            for: node,
            type: type,
            title: subjectTitle,
            isArtworkInteractive: enemyDetail != nil
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
                        corruptionAltarCooldownRemaining: playerSave.corruptionAltarCooldownRemaining
                    ),
                    style: .inspector
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
            labyrinthModifiers: LabyrinthCatalog.modifiers(ids: node.modifierIDs)
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
    enum Style {
        case inspector
        case hexSeal
    }

    @Environment(PlayerSaveStore.self) private var playerSave

    let node: LabyrinthNode
    let type: LabyrinthNodeType
    let pickContext: MysteryEventPickContext
    var style: Style = .inspector

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
                worldSeed: playerSave.worldSeed,
                forcedEventID: nil,
                pinnedEventID: node.mysteryEventID,
                context: pickContext
            )
        default:
            nil
        }
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
