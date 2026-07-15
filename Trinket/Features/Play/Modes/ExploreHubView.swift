import SwiftUI
import TrinketDesignSystem

/// Temporary Explore landing page. The eventual world map can replace this
/// hub without changing the Play tab's top-level Campaign/Explore contract.
struct ExploreHubView: View {
    var body: some View {
        List {
            Section {
                Text("Choose a path and make your own adventure.")
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Available adventures") {
                NavigationLink(value: PlayLaunchDestination.aspectsHub) {
                    destinationRow(
                        title: "Aspects",
                        subtitle: "Attune your party and climb one aspect at a time.",
                        systemImage: "sparkles"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)
                .trinketQuietTapButtonStyle()

                NavigationLink(value: PlayLaunchDestination.labyrinthMap) {
                    destinationRow(
                        title: "The Labyrinth",
                        subtitle: "Descend a shifting path of encounters and rewards.",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
                .trinketQuietTapButtonStyle()
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.exploreHub)
    }

    private func destinationRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(title)
                    .trinketTypography(.button)
                Text(subtitle)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(TrinketDesign.Colors.accent)
        }
        .padding(.vertical, TrinketDesign.Metrics.smallSpacing)
    }
}
