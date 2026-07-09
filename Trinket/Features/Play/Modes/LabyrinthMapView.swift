import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct LabyrinthMapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Depth \(state.deepestDepth)")
                .font(.title2.weight(.semibold))
            Text("The path remembers. Choose a way forward.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var visibleClusters: [LabyrinthCluster] {
        state.clusters
            .filter { $0.depthBand > 0 }
            .filter { cluster in
                cluster.nodeIDs.contains { state.nodes[$0]?.isRevealed == true }
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
                ForEach(clusterNodes(cluster)) { node in
                    nodeCard(node, tint: style?.color)
                        .id(node.id)
                }
            }
        }
        .padding(14)
        .trinketSurface(.base)
        .animation(reduceMotion ? nil : .smooth, value: cluster.id)
    }

    private func clusterNodes(_ cluster: LabyrinthCluster) -> [LabyrinthNode] {
        cluster.nodeIDs.compactMap { state.nodes[$0] }
            .filter(\.isRevealed)
            .sorted { lhs, rhs in
                if lhs.isCleared != rhs.isCleared { return !lhs.isCleared && rhs.isCleared }
                return lhs.id < rhs.id
            }
    }

    @ViewBuilder
    private func nodeCard(_ node: LabyrinthNode, tint: Color?) -> some View {
        let reachable = state.isNodeReachable(node.id)
        let deadly = node.depth > max(appState.roster.highestHeroLevel + 2, 3)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(nodeTitle(node), systemImage: node.type.symbolName)
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

            if deadly, reachable, !node.isCleared, node.type.isCombat {
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
                    Text(node.failCount > 0 ? "Retry" : node.type.primaryActionTitle)
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
        if let enemyID = node.enemyID, let enemy = GameContent.enemy(matching: enemyID) {
            return "\(node.type.title) · \(enemy.combatant.name)"
        }
        return node.type.title
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
        if let guaranteed = modifier.guaranteedNodeType {
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