import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

/// Shared title / narrative / grid scaffolding for mystery item pickers.
private struct MysteryItemChoiceScaffold<Footer: View>: View {
    let title: String
    let titleAccessibilityIdentifier: String
    let narrative: String
    let persistFailureMessage: String?
    let items: [InventoryItem]
    let isDisabled: Bool
    let itemAccessibilityID: (String) -> String
    let onSelectItem: (String) -> Void
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Text(title)
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(titleAccessibilityIdentifier)

                    Text(narrative)
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    mysteryPersistFailureBanner(persistFailureMessage)
                }

                LazyVGrid(
                    columns: TrinketDesign.Metrics.collectionGridItems,
                    spacing: TrinketDesign.Metrics.largeSpacing
                ) {
                    ForEach(items) { item in
                        EncounterItemTile(
                            item: item,
                            showsName: true,
                            isDisabled: isDisabled,
                            accessibilityID: itemAccessibilityID(item.id),
                            onSelect: { onSelectItem(item.id) }
                        )
                    }
                }

                footer()
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
    }
}

struct MysteryItemChoiceContent: View {
    @Bindable var session: MysteryEncounterSession
    let onSelectItem: (String) -> Void

    var body: some View {
        MysteryItemChoiceScaffold(
            title: "Choose a Find",
            titleAccessibilityIdentifier: AccessibilityID.Mystery.chooseItemTitle,
            narrative: "Three relics answer the scrolls. Take one.",
            persistFailureMessage: session.persistFailureMessage,
            items: session.itemCandidates,
            isDisabled: session.isResolvingChoice,
            itemAccessibilityID: AccessibilityID.Mystery.chooseItemCard(itemID:),
            onSelectItem: onSelectItem,
            footer: { EmptyView() }
        )
    }
}

struct MysteryCorruptItemChoiceContent: View {
    @Bindable var session: MysteryEncounterSession
    let onCorruptItem: (String) -> Bool
    let onCancelCorruptSelection: () -> Void

    var body: some View {
        MysteryItemChoiceScaffold(
            title: "Offer an Item",
            titleAccessibilityIdentifier: AccessibilityID.Mystery.corruptItemTitle,
            narrative: "Choose gear to corrupt. The altar remakes it once — forever.",
            persistFailureMessage: session.persistFailureMessage,
            items: session.corruptibleItems,
            isDisabled: session.isResolvingChoice,
            itemAccessibilityID: AccessibilityID.Mystery.corruptItemCard(itemID:),
            onSelectItem: { itemID in
                _ = onCorruptItem(itemID)
            },
            footer: {
                Button("Back") {
                    onCancelCorruptSelection()
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: AccessibilityID.Mystery.corruptCancelButton
                )
                .disabled(session.isResolvingChoice)
            }
        )
    }
}
