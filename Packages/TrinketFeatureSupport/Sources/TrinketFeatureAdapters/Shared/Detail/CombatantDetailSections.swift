import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatantTraitsSection: View, Equatable {
    let traits: [CombatantTraitDefinition]
    let sectionID: String
    let descriptionID: String

    var body: some View {
        TraitListSection(title: "Traits", sectionID: sectionID, items: traits) { trait in
            DetailTraitRow(
                title: trait.name,
                description: trimmed(trait.description),
                descriptionAccessibilityID: descriptionID,
            )
        }
    }
}

struct CombatantLabyrinthSection: View, Equatable {
    let labyrinthModifiers: [LabyrinthModifierDefinition]

    var body: some View {
        TraitListSection(
            title: "Labyrinth",
            sectionID: AccessibilityID.CombatantDetail.labyrinthModifiersSection,
            items: labyrinthModifiers,
        ) { modifier in
            DetailTraitRow(
                title: modifier.title,
                description: trimmed(modifier.effect.description),
                descriptionAccessibilityID: AccessibilityID.CombatantDetail.labyrinthModifierDescription,
            )
        }
    }
}

struct CombatantActiveEffectsSection: View, Equatable {
    let summaries: [EffectSummary]

    var body: some View {
        TraitListSection(title: "Active Effects", items: summaries) { summary in
            let parts = activeEffectParts(summary)
            DetailTraitRow(title: parts.0, description: parts.1, leadingIconKeyword: summary.keyword)
        }
    }
}

private struct TraitListSection<Item: Identifiable, Row: View>: View {
    let title: String
    var sectionID: String?
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    init(title: String, sectionID: String? = nil, items: [Item], @ViewBuilder row: @escaping (Item) -> Row) {
        self.title = title
        self.sectionID = sectionID
        self.items = items
        self.row = row
    }

    var body: some View {
        DetailSection(title, sectionID: sectionID) {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(items) { row($0) }
            }
        }
    }
}

private func trimmed(_ text: String) -> String {
    text.hasSuffix(".") ? String(text.dropLast()) : text
}

private func activeEffectParts(_ summary: EffectSummary) -> (String, String) {
    if let separator = summary.text.range(of: ": ") {
        let title = String(summary.text[..<separator.lowerBound])
        let desc = String(summary.text[separator.upperBound...])
        return (trimmed(title), trimmed(desc))
    }
    return (trimmed(summary.text), trimmed(summary.keyword.rulesText))
}

struct CombatantTalentsSection: View {
    let combatantID: String
    let progression: CombatantProgression
    let unlockedTalents: Set<String>
    let onSelectTree: (TalentTree) -> Void

    var body: some View {
        if let config = CombatantTalentCatalog.configIfAvailable(for: combatantID) {
            let available = progression.availableTalentPoints(unlockedCount: unlockedTalents.count)
            DetailSection("Talents", sectionID: AccessibilityID.CombatantDetail.talentsSection) {
                HStack(spacing: TrinketDesign.Spacing.small) {
                    ForEach(config.trees) { tree in
                        let hasUnallocatedPoints = available > 0
                        let unlockedCount = tree.nodes.count(where: { unlockedTalents.contains($0.id) })
                        Button {
                            onSelectTree(tree)
                        } label: {
                            TalentTreeCard(
                                tree: tree,
                                caption: "\(unlockedCount)/\(tree.nodes.count)",
                                showsShine: hasUnallocatedPoints,
                                accessibilityID: AccessibilityID.CombatantDetail.talentsNode(id: tree.keyword.rawValue),
                            )
                        }
                        .trinketQuietTapButtonStyle()
                    }
                }
                .padding(.vertical, TrinketDesign.Spacing.extraSmall)
            }
        }
    }
}
