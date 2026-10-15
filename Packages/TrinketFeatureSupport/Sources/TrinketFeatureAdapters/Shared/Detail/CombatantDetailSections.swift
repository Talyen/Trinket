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
        TraitListSection(
            title: String(localized: L10n.ui_combatantdetailsections_traits_e0ab4),
            sectionID: sectionID,
            items: traits,
        ) { trait in
            DetailTraitRow(
                title: trait.name,
                description: trimmed(trait.description),
                descriptionAccessibilityID: "\(descriptionID).\(trait.id)",
            )
        }
    }
}

struct CombatantModifiersSection: View, Equatable {
    let nodeModifiers: [NodeModifierDefinition]

    var body: some View {
        TraitListSection(
            title: String(localized: L10n.ui_combatantdetailsections_modifiers_072da),
            sectionID: AccessibilityID.CombatantDetail.nodeModifiersSection,
            items: nodeModifiers,
        ) { modifier in
            DetailTraitRow(
                title: modifier.title,
                description: trimmed(modifier.effect.description),
                descriptionAccessibilityID: AccessibilityID.CombatantDetail.nodeModifierDescription,
                leadingIcon: NodeModifierPresentation.style(for: modifier).icon,
                titleColor: NodeModifierPresentation.style(for: modifier).color,
            )
        }
    }
}

struct CombatantActiveEffectsSection: View {
    @Environment(\.locale) private var locale
    let summaries: [EffectSummary]

    var body: some View {
        TraitListSection(title: String(localized: L10n.ui_combatantdetailsections_active_effects_d01db), items: summaries) { summary in
            DetailTraitRow(
                title: summary.keyword.localizedName(locale: locale),
                description: summary.text,
                leadingIconKeyword: summary.keyword,
                localizedDescription: summary.localizedText(locale: locale),
            )
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

struct CombatantTalentsSection: View {
    let combatantID: String
    let progression: CombatantProgression
    let unlockedTalents: Set<String>
    let onSelectTree: (TalentTree) -> Void

    var body: some View {
        if let config = CombatantTalentCatalog.configIfAvailable(for: combatantID) {
            let available = progression.availableTalentPoints(unlockedCount: unlockedTalents.count)
            let hasUnlockableTalent = config.hasUnlockableNode(
                unlockedNodeIDs: unlockedTalents,
                availablePoints: available,
            )
            DetailSection(
                String(localized: L10n.ui_combatantdetailsections_talents_e8871),
                sectionID: AccessibilityID.CombatantDetail.talentsSection,
            ) {
                HStack(spacing: TrinketDesign.Spacing.small) {
                    ForEach(config.trees) { tree in
                        let unlockedCount = tree.nodes.count(where: { unlockedTalents.contains($0.id) })
                        let isComplete = tree.nodes.allSatisfy { unlockedTalents.contains($0.id) }
                        Button {
                            onSelectTree(tree)
                        } label: {
                            TalentTreeCard(
                                tree: tree,
                                caption: isComplete ? String(localized: L10n.ui_combatantdetailsections_complete_143b2) :
                                    "\(unlockedCount)/\(tree.nodes.count)",
                                showsShine: hasUnlockableTalent && !isComplete,
                                accessibilityID: AccessibilityID.CombatantDetail.talentsNode(id: tree.keyword.rawValue),
                            )
                        }
                        .trinketArtworkCardButtonStyle(pressedScale: TrinketMotion.Interaction.choiceCardPressedScale)
                    }
                }
                .padding(.vertical, TrinketDesign.Spacing.extraSmall)
            }
        }
    }
}
