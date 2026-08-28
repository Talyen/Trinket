import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

private struct MysteryItemChoiceScaffold<Footer: View>: View {
    let title: String
    let titleAccessibilityIdentifier: String
    let narrative: String
    let persistFailureMessage: String?
    let items: [InventoryItem]
    let selectedItemID: String?
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
                            isSelected: selectedItemID == item.id,
                            selectionShineColors: CorruptionShine.borderColors,
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
    @Environment(OptionsStore.self) private var options
    @Bindable var session: MysteryEncounterSession
    let onCorruptItem: (String) -> Bool
    let onCancelCorruptSelection: () -> Void
    @State private var selectedItemID: String?
    @State private var selectionFeedbackTrigger = 0

    var body: some View {
        MysteryItemChoiceScaffold(
            title: "Offer an Item",
            titleAccessibilityIdentifier: AccessibilityID.Mystery.corruptItemTitle,
            narrative: "Choose gear to corrupt. The altar remakes it once — forever.",
            persistFailureMessage: session.persistFailureMessage,
            items: session.corruptibleItems,
            selectedItemID: selectedItemID,
            isDisabled: session.isResolvingChoice,
            itemAccessibilityID: AccessibilityID.Mystery.corruptItemCard(itemID:),
            onSelectItem: { itemID in
                guard selectedItemID != itemID else { return }
                selectedItemID = itemID
                selectionFeedbackTrigger += 1
            },
            footer: {
                VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                    Button("Corrupt") {
                        guard let selectedItemID else { return }
                        _ = onCorruptItem(selectedItemID)
                    }
                    .frame(maxWidth: .infinity)
                    .trinketPrimaryActionButton(
                        tint: TrinketDesign.Colors.destructive,
                        accessibilityIdentifier: AccessibilityID.Mystery.corruptConfirmButton
                    )
                    .trinketCenteredPrimaryAction()
                    .disabled(selectedItemID == nil || session.isResolvingChoice)

                    Button("Back") {
                        onCancelCorruptSelection()
                    }
                    .frame(maxWidth: .infinity)
                    .trinketSecondaryActionButton(
                        accessibilityIdentifier: AccessibilityID.Mystery.corruptCancelButton
                    )
                    .trinketCenteredPrimaryAction()
                    .disabled(session.isResolvingChoice)
                }
            }
        )
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
        .animation(TrinketMotion.Interaction.selection, value: selectedItemID)
    }
}
