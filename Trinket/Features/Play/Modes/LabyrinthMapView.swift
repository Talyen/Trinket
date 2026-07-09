import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct LabyrinthMapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var partyPicker: PartyPickerKind?
    @State private var nodeMessage: StageMapMessage?
    @State private var selectedModifier: LabyrinthModifierDefinition?

    private var state: PlayerLabyrinthState {
        appState.labyrinth.current
    }

    var body: some View {
        Group {
            if state.hasMap {
                mapContent
            } else {
                ContentUnavailableView {
                    Label("Wanderer's Labyrinth", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                } description: {
                    Text("The path remembers. Descend when you are ready.")
                } actions: {
                    Button("Enter") {
                        if let message = appState.enterLabyrinth() {
                            nodeMessage = message
                        }
                    }
                    .trinketPrimaryActionButton()
                    .accessibilityIdentifier(AccessibilityID.Play.labyrinthEnter)
                }
            }
        }
        .navigationTitle("Wanderer's Labyrinth")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.playJourney)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthMap)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Leave") {
                    dismiss()
                }
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthLeave)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    LabyrinthAtlasView()
                } label: {
                    Text("Atlas")
                }
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthAtlas)
            }
        }
        .onAppear {
            if appState.isLabyrinthUnlocked, !state.hasMap {
                _ = appState.enterLabyrinth()
            }
        }
        .sheet(item: $partyPicker) { picker in
            PartyPickerSheet(
                kind: picker,
                combatants: combatants(for: picker),
                onSelect: { combatant in
                    select(combatant, for: picker)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedModifier) { modifier in
            NavigationStack {
                List {
                    Section {
                        Text(modifier.epithet)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Section("Effects") {
                        ForEach(modifierDetailLines(modifier), id: \.self) { line in
                            Text(line)
                        }
                    }
                }
                .navigationTitle(modifier.title)
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .alert(item: $nodeMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var mapContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                ActivePartyPickerRow(
                    hero: appState.roster.activeHero,
                    pet: appState.roster.activePet,
                    onHeroPicker: { partyPicker = .hero },
                    onPetPicker: { partyPicker = .pet }
                )

                ForEach(visibleClusters) { cluster in
                    clusterSection(cluster)
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, 16)
        }
    }

    private var header: some View {
        let focus = focusedCluster
        let biome = focus.flatMap { GameContent.labyrinthBiome(id: $0.biomeID) }
        let modifiers = LabyrinthCatalog.modifiers(ids: focus?.modifierIDs ?? [])
        let style = biome?.keywordBias.visualStyle

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Depth \(state.deepestDepth)")
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier(AccessibilityID.Play.labyrinthDepthBadge)
                if state.deepestDepth >= 10 {
                    Text("Atlas marked")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .trinketGlassChip()
                }
            }

            if let biome {
                Text(biome.title)
                    .font(.headline)
                Text(biome.epithet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("The path remembers. Choose a way forward.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !modifiers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(modifiers.enumerated()), id: \.element.id) { index, modifier in
                            Button {
                                selectedModifier = modifier
                            } label: {
                                Text(modifier.title)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                            }
                            .trinketGlassChip()
                            .foregroundStyle(style?.color ?? .primary)
                            .opacity(reduceMotion ? 1 : 1)
                            .animation(
                                reduceMotion
                                    ? nil
                                    : TrinketMotion.Labyrinth.modifierIn.delay(
                                        Double(index) * TrinketMotion.Labyrinth.modifierStagger
                                    ),
                                value: focus?.id
                            )
                            .accessibilityIdentifier(
                                AccessibilityID.Play.labyrinthModifier(modifier.id.rawValue)
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var focusedCluster: LabyrinthCluster? {
        let reachable = state.reachableNodeIDs()
        if let nodeID = reachable.first, let cluster = state.cluster(for: nodeID) {
            return cluster
        }
        return visibleClusters.last
    }

    private var visibleClusters: [LabyrinthCluster] {
        state.clusters
            .filter { $0.depthBand > 0 }
            .filter { cluster in
                cluster.nodeIDs.contains { id in
                    state.nodes[id]?.isRevealed == true || isFogged(nodeID: id)
                }
            }
            .sorted { $0.depthBand < $1.depthBand }
    }

    @ViewBuilder
    private func clusterSection(_ cluster: LabyrinthCluster) -> some View {
        let biome = GameContent.labyrinthBiome(id: cluster.biomeID)
        let modifiers = LabyrinthCatalog.modifiers(ids: cluster.modifierIDs)
        let style = biome?.keywordBias.visualStyle

        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(biome?.title ?? "Unknown Biome")
                    .font(.headline)
                if let epithet = biome?.epithet {
                    Text(epithet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !modifiers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(modifiers) { modifier in
                            Button {
                                selectedModifier = modifier
                            } label: {
                                Text(modifier.title)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
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

            LazyVStack(spacing: 10) {
                ForEach(clusterDisplayNodes(cluster)) { entry in
                    switch entry {
                    case let .revealed(node):
                        nodeCard(node, tint: style?.color)
                            .id(node.id)
                    case let .fog(node):
                        fogCard(node)
                            .id(node.id)
                    }
                }
            }
        }
        .padding(14)
        .trinketSurface(.base)
        .animation(
            reduceMotion ? nil : TrinketMotion.Labyrinth.clusterReveal,
            value: cluster.id
        )
    }

    private enum ClusterDisplayNode: Identifiable {
        case revealed(LabyrinthNode)
        case fog(LabyrinthNode)

        var id: String {
            switch self {
            case let .revealed(node), let .fog(node):
                return node.id
            }
        }
    }

    private func clusterDisplayNodes(_ cluster: LabyrinthCluster) -> [ClusterDisplayNode] {
        cluster.nodeIDs.compactMap { id -> ClusterDisplayNode? in
            guard let node = state.nodes[id] else { return nil }
            if node.isRevealed {
                return .revealed(node)
            }
            if isFogged(nodeID: id) {
                return .fog(node)
            }
            return nil
        }
        .sorted { lhs, rhs in
            let left = displaySortKey(lhs)
            let right = displaySortKey(rhs)
            if left.cleared != right.cleared { return !left.cleared && right.cleared }
            return left.id < right.id
        }
    }

    private func displaySortKey(_ entry: ClusterDisplayNode) -> (cleared: Bool, id: String) {
        switch entry {
        case let .revealed(node):
            return (node.isCleared, node.id)
        case let .fog(node):
            return (false, node.id)
        }
    }

    /// Fog silhouettes: unrevealed nodes that are one edge beyond a revealed uncleared or cleared node.
    private func isFogged(nodeID: String) -> Bool {
        guard let node = state.nodes[nodeID], !node.isRevealed, !node.isCleared else { return false }
        return state.nodes.values.contains { source in
            source.isRevealed && source.outgoingIDs.contains(nodeID)
        }
    }

    @ViewBuilder
    private func fogCard(_ node: LabyrinthNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hidden path", systemImage: "eye.slash")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Clear a path to reveal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trinketSurface(.secondary)
        .opacity(0.55)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthFogNode(node.id))
    }

    @ViewBuilder
    private func nodeCard(_ node: LabyrinthNode, tint: Color?) -> some View {
        let reachable = state.isNodeReachable(node.id)
        let deadly = node.depth > max(appState.roster.highestHeroLevel + 2, 3)
        let type = node.type.canonical

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(nodeTitle(node), systemImage: type.symbolName)
                    .font(.body.weight(.semibold))
                Spacer()
                if node.isCleared {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Cleared")
                } else if !reachable {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Locked")
                } else if node.failCount > 0 {
                    Text("Retry")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if type == .warden, reachable, !node.isCleared {
                Text("Warden")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            if deadly, reachable, !node.isCleared, type.isCombat {
                Text("Deadly")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if reachable, !node.isCleared {
                Button {
                    if let message = appState.handleLabyrinthNodeAction(nodeID: node.id) {
                        nodeMessage = message
                    }
                } label: {
                    Text(node.failCount > 0 ? "Retry" : type.primaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(tint ?? .accentColor)
                .disabled(appState.battle.activeBattle != nil)
            }
        }
        .padding(12)
        .trinketSurface(node.isCleared ? .secondary : .elevated)
        .opacity(node.isCleared ? 0.72 : 1)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNode(node.id))
    }

    private func nodeTitle(_ node: LabyrinthNode) -> String {
        let type = node.type.canonical
        if let enemyID = node.enemyID, let enemy = GameContent.enemy(matching: enemyID) {
            return "\(type.title) · \(enemy.combatant.name)"
        }
        return type.title
    }

    private func modifierDetailLines(_ modifier: LabyrinthModifierDefinition) -> [String] {
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

    private func combatants(for picker: PartyPickerKind) -> [Combatant] {
        switch picker {
        case .hero: return appState.roster.heroes
        case .pet: return appState.roster.pets
        }
    }

    private func select(_ combatant: Combatant, for picker: PartyPickerKind) {
        var updatedRoster = appState.roster.current
        switch picker {
        case .hero:
            updatedRoster.setActiveHero(combatant)
        case .pet:
            updatedRoster.setActivePet(combatant)
        }
        appState.roster.current = updatedRoster
    }
}
