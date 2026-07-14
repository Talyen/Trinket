import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct LabyrinthMapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var nodeMessage: StageMapMessage?
    @State private var selectedModifier: LabyrinthModifierDefinition?

    let onBattleStart: () -> Void

    init(onBattleStart: @escaping () -> Void = {}) {
        self.onBattleStart = onBattleStart
    }

    private var state: PlayerLabyrinthState {
        appState.labyrinth
    }

    var body: some View {
        Group {
            if state.hasMap {
                mapContent
            } else {
                emptyState
            }
        }
        .navigationTitle("The Labyrinth")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
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
            if !state.hasMap {
                _ = appState.enterLabyrinth()
            }
        }
        .sheet(item: $selectedModifier) { modifier in
            NavigationStack {
                List {
                    Section {
                        Text(modifier.epithet)
                            .trinketTypography(.secondaryBody)
                            .foregroundStyle(.secondary)
                    }
                    Section("Effects") {
                        ForEach(LabyrinthMapPresentation.modifierDetailLines(modifier), id: \.self) { line in
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("The Labyrinth", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
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

    private var mapContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                header

                ForEach(visibleClusters) { cluster in
                    LabyrinthMapClusterSection(
                        cluster: cluster,
                        state: state,
                        onSelectModifier: { selectedModifier = $0 },
                        onBattleStart: onBattleStart,
                        onNodeMessage: { nodeMessage = $0 }
                    )
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
        }
    }

    private var header: some View {
        let focus = focusedCluster
        let biome = focus.flatMap { GameContent.labyrinthBiome(id: $0.biomeID) }
        let modifiers = LabyrinthCatalog.modifiers(ids: focus?.modifierIDs ?? [])
        let style = biome?.keywordBias.visualStyle

        return VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text("Depth \(state.deepestDepth)")
                    .trinketTypography(.sectionTitle)
                    .accessibilityIdentifier(AccessibilityID.Play.labyrinthDepthBadge)
                if state.deepestDepth >= 10 {
                    Text("Atlas marked")
                        .trinketTypography(.badge)
                        .trinketGlassChip(.compact)
                }
            }

            if let biome {
                Text(biome.title)
                    .trinketTypography(.cardTitle)
                Text(biome.epithet)
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
            } else {
                Text("The path remembers. Choose a way forward.")
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
            }

            if !modifiers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(Array(modifiers.enumerated()), id: \.element.id) { index, modifier in
                            Button {
                                selectedModifier = modifier
                            } label: {
                                Text(modifier.title)
                                    .trinketTypography(.badge)
                            }
                            .trinketGlassChip()
                            .foregroundStyle(style?.color ?? .primary)
                            .animation(
                                TrinketMotion.Labyrinth.modifierIn.delay(
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
                    state.nodes[id]?.isRevealed == true
                        || LabyrinthMapPresentation.isFogged(nodeID: id, in: state)
                }
            }
            .sorted { $0.depthBand < $1.depthBand }
    }
}
