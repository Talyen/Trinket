import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

enum LabyrinthMapPresentation {
    enum ClusterDisplayNode: Identifiable {
        case revealed(LabyrinthNode)
        case fog(LabyrinthNode)

        var id: String {
            switch self {
            case let .revealed(node), let .fog(node):
                node.id
            }
        }
    }

    static func isFogged(nodeID: String, in state: PlayerLabyrinthState) -> Bool {
        guard let node = state.nodes[nodeID], !node.isRevealed, !node.isCleared else { return false }
        return state.nodes.values.contains { source in
            source.isRevealed && source.outgoingIDs.contains(nodeID)
        }
    }

    static func displayNodes(
        for cluster: LabyrinthCluster,
        in state: PlayerLabyrinthState
    ) -> [ClusterDisplayNode] {
        cluster.nodeIDs.compactMap { id -> ClusterDisplayNode? in
            guard let node = state.nodes[id] else { return nil }
            if node.isRevealed {
                return .revealed(node)
            }
            if isFogged(nodeID: id, in: state) {
                return .fog(node)
            }
            return nil
        }
        .sorted { lhs, rhs in
            let left = sortKey(lhs)
            let right = sortKey(rhs)
            if left.cleared != right.cleared {
                return !left.cleared && right.cleared
            }
            return left.id < right.id
        }
    }

    static func nodeTitle(_ node: LabyrinthNode) -> String {
        let type = node.type.canonical
        if let enemyID = node.enemyID, let enemy = GameContent.enemy(matching: enemyID) {
            return "\(type.title) · \(enemy.combatant.name)"
        }
        return type.title
    }

    static func modifierDetailLines(_ modifier: LabyrinthModifierDefinition) -> [String] {
        var lines: [String] = []
        if modifier.enemyPowerPercent != 0 {
            lines.append("Enemy power +\(modifier.enemyPowerPercent)%")
        }
        if modifier.goldPercent != 0 {
            lines.append("Gold +\(modifier.goldPercent)%")
        }
        if modifier.xpPercent != 0 {
            lines.append("Experience +\(modifier.xpPercent)%")
        }
        if modifier.itemDropBonusPercent != 0 {
            lines.append("Item finds +\(modifier.itemDropBonusPercent)%")
        }
        if modifier.astralChanceBonusPercent != 0 {
            lines.append("Astral chance +\(modifier.astralChanceBonusPercent)%")
        }
        if let bias = modifier.keywordBias {
            lines.append("Spoils lean toward \(bias.rawValue)")
        }
        if let guaranteed = modifier.guaranteedNodeType?.canonical {
            lines.append("Guarantees a \(guaranteed.title)")
        }
        if lines.isEmpty {
            lines.append("Changes what you find in this cluster.")
        }
        return lines
    }

    private static func sortKey(_ entry: ClusterDisplayNode) -> (cleared: Bool, id: String) {
        switch entry {
        case let .revealed(node):
            (node.isCleared, node.id)
        case let .fog(node):
            (false, node.id)
        }
    }
}

struct LabyrinthMapClusterSection: View {
    @Environment(AppState.self) private var appState

    let cluster: LabyrinthCluster
    let state: PlayerLabyrinthState
    let onSelectModifier: (LabyrinthModifierDefinition) -> Void
    let onBattleStart: () -> Void
    let onNodeMessage: (StageMapMessage) -> Void

    var body: some View {
        let biome = GameContent.labyrinthBiome(id: cluster.biomeID)
        let modifiers = LabyrinthCatalog.modifiers(ids: cluster.modifierIDs)
        let style = biome?.keywordBias.visualStyle

        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(biome?.title ?? "Unknown Biome")
                    .trinketTypography(.cardTitle)
                if let epithet = biome?.epithet {
                    Text(epithet)
                        .trinketTypography(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !modifiers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(modifiers) { modifier in
                            Button {
                                onSelectModifier(modifier)
                            } label: {
                                Text(modifier.title)
                                    .trinketTypography(.badge)
                            }
                            .trinketGlassChip()
                            .foregroundStyle(style?.color ?? .primary)
                            .accessibilityIdentifier(
                                AccessibilityID.Play.labyrinthModifier(modifier.id.rawValue)
                            )
                        }
                    }
                }
            }

            LazyVStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                ForEach(LabyrinthMapPresentation.displayNodes(for: cluster, in: state)) { entry in
                    switch entry {
                    case let .revealed(node):
                        LabyrinthMapNodeCard(
                            node: node,
                            tint: style?.color,
                            state: state,
                            onBattleStart: onBattleStart,
                            onMessage: onNodeMessage
                        )
                        .id(node.id)
                    case let .fog(node):
                        LabyrinthMapFogCard(node: node)
                            .id(node.id)
                    }
                }
            }
        }
        .trinketSurface(.base)
        .animation(TrinketMotion.Labyrinth.clusterReveal, value: cluster.id)
    }
}

struct LabyrinthMapFogCard: View {
    let node: LabyrinthNode

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Label("Hidden path", systemImage: "eye.slash")
                .trinketTypography(.button)
                .foregroundStyle(.secondary)
            Text("Clear a path to reveal")
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trinketSurface(.secondary)
        .opacity(0.55)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthFogNode(node.id))
    }
}

struct LabyrinthMapNodeCard: View {
    @Environment(AppState.self) private var appState

    let node: LabyrinthNode
    let tint: Color?
    let state: PlayerLabyrinthState
    let onBattleStart: () -> Void
    let onMessage: (StageMapMessage) -> Void

    var body: some View {
        let reachable = state.isNodeReachable(node.id)
        let deadly = node.depth > max(appState.roster.highestHeroLevel + 2, 3)
        let type = node.type.canonical

        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            HStack {
                Label(LabyrinthMapPresentation.nodeTitle(node), systemImage: type.symbolName)
                    .trinketTypography(.button)
                Spacer()
                if node.isCleared {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TrinketDesign.Colors.success)

                } else if node.failCount > 0, reachable {
                    Text("Retry")
                        .trinketTypography(.badge)
                        .foregroundStyle(TrinketDesign.Colors.warning)
                }
            }

            if type == .warden, reachable, !node.isCleared {
                Text("Warden")
                    .trinketTypography(.badge)
                    .foregroundStyle(TrinketDesign.Colors.arcane)
            }

            if deadly, reachable, !node.isCleared, type.isCombat {
                Text("Deadly")
                    .trinketTypography(.badge)
                    .foregroundStyle(TrinketDesign.Colors.warning)
            }

            if reachable, !node.isCleared {
                if type.isCombat {
                    BattlePartyInlinePicker(accentColor: tint ?? TrinketDesign.Colors.accent)
                }

                Button {
                    if type.isCombat {
                        if let message = appState.startLabyrinthBattle(nodeID: node.id) {
                            onMessage(message)
                        } else {
                            onBattleStart()
                        }
                    } else if let message = appState.handleLabyrinthNodeAction(nodeID: node.id) {
                        onMessage(message)
                    }
                } label: {
                    Text(node.failCount > 0 ? "Retry" : type.primaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(tint ?? TrinketDesign.Colors.accent)
                .disabled(appState.battle.activeBattle != nil)
            }
        }
        .trinketSurface(node.isCleared ? .secondary : .elevated)
        .trinketLockedCardEffect(
            isLocked: !reachable && !node.isCleared,
            text: !reachable && !node.isCleared ? "Locked" : nil,
            cornerRadius: TrinketDesign.Corners.card
        )
        .opacity(node.isCleared ? 0.72 : 1)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNode(node.id))
    }
}
