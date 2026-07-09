import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

struct CollectionSearchResultsView: View {
    let query: String
    let results: CollectionSearch.Results
    let onSelectItem: (InventoryItem) -> Void
    let onSelectCombatant: (CombatantDetailContext) -> Void

    var body: some View {
        if results.isEmpty {
            ContentUnavailableView(
                "No Results Found",
                systemImage: "questionmark.magnifyingglass",
                description: Text("No match for \"\(query)\".")
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.Collection.searchNoResults)
        } else {
            List {
                combatantResultsSection(
                    title: "Heroes",
                    kind: .hero,
                    combatants: results.heroes
                )
                combatantResultsSection(
                    title: "Pets",
                    kind: .pet,
                    combatants: results.pets
                )

                if !results.items.isEmpty {
                    CollectionSearchResultSection(title: "Items", items: results.items) { item in
                        Button {
                            onSelectItem(item)
                        } label: {
                            ItemCard(
                                item: item,
                                showsAffixCount: true
                            )
                            .collectionShelfCardWidth()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(item.displayName) item card")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier(AccessibilityID.Collection.searchResults)
        }
    }

    @ViewBuilder
    private func combatantResultsSection(
        title: String,
        kind: CombatantDetailContext.Kind,
        combatants: [Combatant]
    ) -> some View {
        if !combatants.isEmpty {
            CollectionSearchResultSection(title: title, items: combatants) { combatant in
                Button {
                    onSelectCombatant(CombatantDetailContext(kind: kind, combatantID: combatant.id))
                } label: {
                    CombatantCard(combatant: combatant)
                        .collectionShelfCardWidth()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(combatant.name) collection card")
            }
        }
    }
}

struct CollectionSearchResultSection<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        Section(title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: TrinketDesign.Metrics.collectionShelfCardSpacing) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, TrinketDesign.Metrics.shelfVerticalPadding)
            }
            .contentMargins(
                .horizontal,
                TrinketDesign.Metrics.collectionShelfHorizontalMargin,
                for: .scrollContent
            )
            .scrollTargetBehavior(.viewAligned)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
        }
    }
}
