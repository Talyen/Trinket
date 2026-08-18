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

struct MysteryCorruptItemChoiceContent: View {
    @Bindable var session: MysteryEncounterSession
    let onCorruptItem: (String) -> Bool
    let onCancelCorruptSelection: () -> Void
    @State private var pendingCorruptItemID: String?

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
                pendingCorruptItemID = itemID
            },
            footer: {
                Button("Back") {
                    onCancelCorruptSelection()
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: AccessibilityID.Mystery.corruptCancelButton
                )
                .trinketCenteredPrimaryAction()
                .disabled(session.isResolvingChoice)
            }
        )
        .confirmationDialog(
            "Corrupt this item forever?",
            isPresented: Binding(
                get: { pendingCorruptItemID != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingCorruptItemID = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Corrupt", role: .destructive) {
                if let itemID = pendingCorruptItemID {
                    _ = onCorruptItem(itemID)
                }
                pendingCorruptItemID = nil
            }
            Button("Cancel", role: .cancel) {
                pendingCorruptItemID = nil
            }
        }
    }
}
