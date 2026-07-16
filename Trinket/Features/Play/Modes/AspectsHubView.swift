import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct AspectsHubView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                Text("Attune a Hero and Companion. Climb one Aspect at a time.")
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Damage Aspects") {
                ForEach(GameContent.aspects) { aspect in
                    aspectRow(aspect)
                }
            }
        }
        .navigationTitle("Aspects")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.aspectsHub)
    }

    @ViewBuilder
    private func aspectRow(_ aspect: AspectDefinition) -> some View {
        let unlocked = AspectUnlock.isUnlocked(aspect, progress: appState.aspects)
        let cleared = appState.aspects.highestClearedFloor(for: aspect.id.rawValue)
        let style = aspect.keyword.visualStyle

        if unlocked {
            NavigationLink {
                AspectClimbView(aspectID: aspect.id)
            } label: {
                aspectLabel(aspect, style: style, trailing: floorLabel(cleared: cleared, floorCount: aspect.floorCount))
            }
            .accessibilityIdentifier(AccessibilityID.Play.aspectRow(aspect.id.rawValue))
        } else {
            aspectLabel(
                aspect,
                style: style,
                trailing: nil,
                locked: true,
                lockText: "Locked"
            )
            .accessibilityIdentifier(AccessibilityID.Play.aspectRow(aspect.id.rawValue))
        }
    }

    private func aspectLabel(
        _ aspect: AspectDefinition,
        style: Keyword.VisualStyle,
        trailing: String?,
        locked: Bool = false,
        lockText: String? = nil
    ) -> some View {
        HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            Image(systemName: style.symbolName)
                .trinketTypography(.button)
                .foregroundStyle(style.prefersDarkForeground ? Color.primary : style.color)
                .frame(width: 28, height: 28)
                .trinketGlassChip()

            VStack(alignment: .leading, spacing: 2) {
                Text(aspect.title)
                    .trinketTypography(.button)
                Text(aspect.epithet)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: TrinketDesign.Metrics.smallSpacing)

            if let trailing {
                Text(trailing)
                    .trinketTypography(.badge)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .trinketLockedCardEffect(
            isLocked: locked,
            text: lockText
        )
        .animation(.smooth, value: locked)
    }

    private func floorLabel(cleared: Int, floorCount: Int) -> String {
        if cleared >= floorCount {
            return "Cleared"
        }
        if cleared == 0 {
            return "Floor 1"
        }
        return "Floor \(min(cleared + 1, floorCount))"
    }
}
