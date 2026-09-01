import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct CombatantStatsSection: View {
    let combatBuild: CombatBuild
    let combatantRole: Combatant.Role
    let battleHealth: Int?
    let battleMana: Int?

    var body: some View {
        DetailSection("Stats", sectionID: AccessibilityID.CombatantDetail.statsSection) {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                    LabeledContent {
                        Text("\(battleHealth ?? combatBuild.effectiveMaxHealth)/\(combatBuild.effectiveMaxHealth)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(
                                TrinketMotion.Interaction.selection,
                                value: battleHealth ?? combatBuild.effectiveMaxHealth,
                            )
                    } label: {
                        Text("Health").trinketTypography(.body).foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier(AccessibilityID.CombatantDetail.healthStat)

                    if combatantRole != .enemy, combatBuild.effectiveMaxMana > 0 {
                        LabeledContent {
                            Text("\(battleMana ?? combatBuild.effectiveMaxMana)/\(combatBuild.effectiveMaxMana)")
                                .trinketTypography(.statValue)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                                .animation(
                                    TrinketMotion.Interaction.selection,
                                    value: battleMana ?? combatBuild.effectiveMaxMana,
                                )
                        } label: {
                            Text("Mana").trinketTypography(.body).foregroundStyle(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .trinketSurface(.secondary)

                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                    LabeledContent {
                        Text("\(combatBuild.combatant.primaryStats.strength)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    } label: {
                        Text("Strength").trinketTypography(.body).foregroundStyle(.primary)
                    }
                    LabeledContent {
                        Text("\(combatBuild.combatant.primaryStats.agility)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    } label: {
                        Text("Agility").trinketTypography(.body).foregroundStyle(.primary)
                    }
                    LabeledContent {
                        Text("\(combatBuild.combatant.primaryStats.toughness)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    } label: {
                        Text("Toughness").trinketTypography(.body).foregroundStyle(.primary)
                    }
                    LabeledContent {
                        Text("\(combatBuild.combatant.primaryStats.intellect)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    } label: {
                        Text("Intellect").trinketTypography(.body).foregroundStyle(.primary)
                    }
                    LabeledContent {
                        Text("\(combatBuild.combatant.primaryStats.wisdom)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    } label: {
                        Text("Wisdom").trinketTypography(.body).foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .trinketSurface(.secondary)
            }
        }
    }
}

struct CombatantTraitsSection: View {
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

struct CombatantLabyrinthSection: View {
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

struct CombatantActiveEffectsSection: View {
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
        let config = CombatantTalentCatalog.config(for: combatantID)
        let available = progression.availableTalentPoints(unlockedCount: unlockedTalents.count)
        return DetailSection("Talents", sectionID: AccessibilityID.CombatantDetail.talentsSection) {
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
