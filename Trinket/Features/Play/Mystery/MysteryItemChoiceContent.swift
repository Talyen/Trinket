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
    @State private var visibleItemIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Layout.contentMargin) {
                VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
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
                    columns: TrinketDesign.Layout.collectionGridItems,
                    spacing: TrinketDesign.Spacing.large,
                ) {
                    ForEach(items) { item in
                        EncounterItemTile(
                            item: item,
                            showsName: true,
                            isSelected: selectedItemID == item.id,
                            selectionShineColors: Shine.corruptionBorderColors,
                            isDisabled: isDisabled,
                            accessibilityID: itemAccessibilityID(item.id),
                            onSelect: { onSelectItem(item.id) },
                        )
                        .onAppear { visibleItemIDs.insert(item.id) }
                        .onDisappear { visibleItemIDs.remove(item.id) }
                    }
                }
            }
            .padding(TrinketDesign.Spacing.extraLarge)
        }
        .safeAreaInset(edge: .bottom) {
            footer()
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.vertical, TrinketDesign.Spacing.medium)
        }
        .onChange(of: items.map(\.id)) { _, _ in
            visibleItemIDs.formIntersection(items.lazy.map(\.id))
        }
        .task(id: visibleItemIDs) {
            await ArtworkViewportPrewarm.prewarm(
                orderedItems: items,
                visibleIDs: visibleItemIDs,
                currentVisibleIDs: { visibleItemIDs },
                thumbnailName: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
                prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
            )
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
            narrative: "Choose gear to corrupt. The altar remakes it once, forever.",
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
                HStack(spacing: TrinketDesign.Spacing.medium) {
                    Button("Back") {
                        onCancelCorruptSelection()
                    }
                    .frame(maxWidth: .infinity)
                    .trinketSecondaryActionButton(
                        accessibilityIdentifier: AccessibilityID.Mystery.corruptCancelButton,
                    )
                    .disabled(session.isResolvingChoice)

                    Button("Corrupt") {
                        guard let selectedItemID else { return }
                        _ = onCorruptItem(selectedItemID)
                    }
                    .frame(maxWidth: .infinity)
                    .trinketPrimaryActionButton(
                        tint: TrinketDesign.Colors.destructive,
                        accessibilityIdentifier: AccessibilityID.Mystery.corruptConfirmButton,
                    )
                    .disabled(selectedItemID == nil || session.isResolvingChoice)
                }
            },
        )
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .animation(TrinketMotion.Interaction.selection, value: selectedItemID)
    }
}
