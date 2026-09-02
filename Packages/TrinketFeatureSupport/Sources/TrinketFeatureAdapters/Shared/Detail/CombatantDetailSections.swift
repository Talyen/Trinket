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
        DetailSection("Traits", sectionID: sectionID) {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(traits) { trait in
                    DetailTraitRow(
                        title: trait.name,
                        description: trait.description.hasSuffix(".") ? String(trait.description.dropLast()) : trait.description,
                        descriptionAccessibilityID: descriptionID,
                    )
                }
            }
        }
    }
}

struct CombatantLabyrinthSection: View, Equatable {
    let labyrinthModifiers: [LabyrinthModifierDefinition]

    var body: some View {
        DetailSection("Labyrinth", sectionID: AccessibilityID.CombatantDetail.labyrinthModifiersSection) {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(labyrinthModifiers) { modifier in
                    DetailTraitRow(
                        title: modifier.title,
                        description: modifier.effect.description.hasSuffix(".")
                            ? String(modifier.effect.description.dropLast()) : modifier.effect.description,
                        descriptionAccessibilityID: AccessibilityID.CombatantDetail.labyrinthModifierDescription,
                    )
                }
            }
        }
    }
}

struct CombatantActiveEffectsSection: View, Equatable {
    let summaries: [EffectSummary]

    var body: some View {
        DetailSection("Active Effects") {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(summaries) { summary in
                    let parts: (String, String) = {
                        if let separator = summary.text.range(of: ": ") {
                            let title = String(summary.text[..<separator.lowerBound])
                            let desc = String(summary.text[separator.upperBound...])
                            return (
                                title.hasSuffix(".") ? String(title.dropLast()) : title,
                                desc.hasSuffix(".") ? String(desc.dropLast()) : desc,
                            )
                        }
                        return (
                            summary.text.hasSuffix(".") ? String(summary.text.dropLast()) : summary.text,
                            summary.keyword.rulesText.hasSuffix(".") ? String(summary.keyword.rulesText.dropLast()) : summary.keyword
                                .rulesText,
                        )
                    }()
                    DetailTraitRow(title: parts.0, description: parts.1, leadingIconKeyword: summary.keyword)
                }
            }
        }
    }
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
