import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct MysteryCorruptItemChoiceContent: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: MysteryEncounterSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Text("Offer an Item")
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(AccessibilityID.Mystery.corruptItemTitle)

                    Text("Choose gear to corrupt. The altar remakes it once — forever.")
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    mysteryPersistFailureBanner(session.persistFailureMessage)
                }

                LazyVGrid(
                    columns: TrinketDesign.Metrics.collectionGridItems,
                    spacing: TrinketDesign.Metrics.largeSpacing
                ) {
                    ForEach(session.corruptibleItems) { item in
                        EncounterItemTile(
                            item: item,
                            showsName: true,
                            isDisabled: session.isResolvingChoice,
                            accessibilityID: AccessibilityID.Mystery.corruptItemCard(itemID: item.id),
                            onSelect: { _ = appState.corruptActiveMysteryItem(itemID: item.id) }
                        )
                    }
                }

                Button("Back") {
                    appState.cancelActiveMysteryCorruptSelection()
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: AccessibilityID.Mystery.corruptCancelButton
                )
                .disabled(session.isResolvingChoice)
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
    }
}

struct MysteryCorruptionRevealContent: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: MysteryEncounterSession
    let result: ItemCorruptionResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Text("Corrupted")
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(AccessibilityID.Mystery.corruptionRevealTitle)

                    Text(result.item.displayName)
                        .trinketTypography(.rowTitle)

                    Text(
                        result.item.rarity.label.uppercased()
                            + (result.item.isCorrupted ? " · CORRUPTED" : "")
                    )
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(.secondary)
                }

                ItemArtwork(item: result.item)
                    .frame(maxWidth: 220)
                    .frame(maxWidth: .infinity)

                DetailSection("What Changed") {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(Array(result.effects.enumerated()), id: \.offset) { _, effect in
                            DetailTraitRow(description: effect.displayText)
                        }
                    }
                }

                DetailSection("Traits") {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(result.item.affixes) { affix in
                            DetailTraitRow(description: affix.description)
                        }
                    }
                }

                mysteryPersistFailureBanner(session.persistFailureMessage)

                Button("Continue") {
                    _ = appState.finishActiveMysteryCorruptionReveal()
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: AccessibilityID.Mystery.corruptionContinueButton
                )
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
    }
}

extension CorruptionEffectSummary {
    var displayText: String {
        switch self {
        case let .addedAffix(title):
            "Added \(title)"
        case let .removedAffix(title):
            "Removed \(title)"
        case let .replacedAffix(from, to):
            "Replaced \(from) with \(to)"
        case let .bumpedUp(affixTitle):
            "Empowered \(affixTitle)"
        case let .bumpedDown(affixTitle):
            "Weakened \(affixTitle)"
        case .upgradedRarity:
            "Became Astral"
        }
    }
}
