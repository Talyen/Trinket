import SwiftUI
import TrinketDesignSystem

struct ModesView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    AspectsHubView()
                } label: {
                    modeRow(
                        title: "Aspects",
                        subtitle: "Climb by affinity. Attune a Hero and Pet.",
                        systemImage: "sparkles"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)

                lockedModeRow(
                    title: "Reliquary Gauntlet",
                    subtitle: "Opens later",
                    systemImage: "shield.lefthalf.filled"
                )
                .disabled(true)
                lockedModeRow(
                    title: "Astral Hunt",
                    subtitle: "Opens later",
                    systemImage: "scope"
                )
                .disabled(true)
                lockedModeRow(
                    title: "Wanderer's Labyrinth",
                    subtitle: "Opens later",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
                .disabled(true)
            } footer: {
                Text("Other paths. Same battles. Different reasons to fight.")
            }
        }
        .navigationTitle("Modes")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.denseList)
        .accessibilityIdentifier(AccessibilityID.Play.modesScreen)
    }

    private func modeRow(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private func lockedModeRow(title: String, subtitle: String, systemImage: String) -> some View {
        modeRow(title: title, subtitle: subtitle, systemImage: systemImage)
            .foregroundStyle(.secondary)
            .opacity(0.72)
    }
}
