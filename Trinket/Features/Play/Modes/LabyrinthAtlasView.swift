import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

struct LabyrinthAtlasView: View {
    @Environment(AppState.self) private var appState

    private var state: PlayerLabyrinthState {
        appState.labyrinth.current
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Deepest Depth", value: "\(state.deepestDepth)")
                if state.deepestDepth >= 10 {
                    Text("Marked in the Atlas")
                        .trinketTypography(.badge)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Play.labyrinthDepthBadge)
                }
            }

            Section("Biomes") {
                let biomes = GameContent.labyrinthBiomes.filter {
                    state.discoveredBiomeIDs.contains($0.id.rawValue)
                }
                if biomes.isEmpty {
                    Text("Places you meet are recorded here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(biomes) { biome in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(biome.title)
                                .trinketTypography(.button)
                            Text(biome.epithet)
                                .trinketTypography(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Modifiers") {
                let modifiers = GameContent.labyrinthModifiers.filter {
                    state.discoveredModifierIDs.contains($0.id.rawValue)
                }
                if modifiers.isEmpty {
                    Text("Powers you meet are recorded here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(modifiers) { modifier in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(modifier.title)
                                .trinketTypography(.button)
                            Text(modifier.epithet)
                                .trinketTypography(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !state.claimedMilestoneDepths.isEmpty {
                Section("Milestones") {
                    ForEach(state.claimedMilestoneDepths.sorted(), id: \.self) { depth in
                        Text("Depth \(depth)")
                    }
                }
            }
        }
        .navigationTitle("Atlas")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.denseList)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthAtlas)
    }
}
