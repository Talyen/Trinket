import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct AspectsHubView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            Section {
                Text("Attune a Hero and Pet. Climb one Aspect at a time.")
                    .font(.subheadline)
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
        .trinketScreenBackground(.denseList)
        .accessibilityIdentifier(AccessibilityID.Play.aspectsHub)
    }

    @ViewBuilder
    private func aspectRow(_ aspect: AspectDefinition) -> some View {
        let unlocked = AspectUnlock.isUnlocked(aspect, progress: appState.aspects.current)
        let cleared = appState.aspects.current.highestClearedFloor(for: aspect.id.rawValue)
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
                trailing: AspectUnlock.unlockHint(for: aspect),
                locked: true
            )
            .accessibilityIdentifier(AccessibilityID.Play.aspectRow(aspect.id.rawValue))
        }
    }

    private func aspectLabel(
        _ aspect: AspectDefinition,
        style: Keyword.VisualStyle,
        trailing: String,
        locked: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: style.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(style.prefersDarkForeground ? Color.primary : style.color)
                .frame(width: 28, height: 28)
                .trinketGlassChip()
                .opacity(locked ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(aspect.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(locked ? .secondary : .primary)
                Text(aspect.epithet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(trailing)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .opacity(locked ? 0.8 : 1)
        .animation(reduceMotion ? nil : .smooth, value: locked)
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
