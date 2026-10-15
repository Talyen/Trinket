import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryScaffold<Footer: View>: View {
    let title: String
    let titleAccessibilityIdentifier: String
    let narrative: String
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
                    GameLabel(title)
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(titleAccessibilityIdentifier)

                    GameLabel(narrative)
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
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
        MysteryScaffold(
            title: String(localized: L10n.ui_mysteryitemchoicecontent_offer_an_item_0c482),
            titleAccessibilityIdentifier: AccessibilityID.Mystery.corruptItemTitle,
            narrative: String(localized: L10n.ui_mysteryitemchoicecontent_choose_gear_to_corrupt_the_altar_remakes_it_o_b4084),
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
                    Button {
                        onCancelCorruptSelection()
                    } label: {
                        Text(L10n.ui_mysteryitemchoicecontent_back_76900)
                            .frame(maxWidth: .infinity)
                    }
                    .trinketSecondaryActionButton(
                        accessibilityIdentifier: AccessibilityID.Mystery.corruptCancelButton,
                    )
                    .disabled(session.isResolvingChoice)

                    Button {
                        guard let selectedItemID else { return }
                        _ = onCorruptItem(selectedItemID)
                    } label: {
                        Text(L10n.ui_mysteryitemchoicecontent_corrupt_65ab9)
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton(
                        tint: TrinketDesign.Colors.destructive,
                        accessibilityIdentifier: AccessibilityID.Mystery.corruptConfirmButton,
                    )
                    .disabled(selectedItemID == nil || session.isResolvingChoice)
                }
            },
        )
        .onChange(of: session.corruptibleItems.map(\.id)) { _, ids in
            if let selectedItemID, !ids.contains(selectedItemID) {
                self.selectedItemID = nil
            }
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .animation(TrinketMotion.Interaction.selection, value: selectedItemID)
    }
}
