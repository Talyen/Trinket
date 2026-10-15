import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryCorruptionRevealContent: View {
    @Environment(\.locale) private var locale
    @Bindable var session: MysteryEncounterSession
    let result: ItemCorruptionDetail
    let onFinish: () -> Bool

    var body: some View {
        DetailHeroScrollShell(
            title: result.item.localizedDisplayName(locale: locale),
            header: { baseHeight in
                DetailHeroHeader(
                    eyebrow: eyebrow(for: result.item),
                    eyebrowIndicators: result.effects.filter { $0 == .upgradedRarity }.map(\.indicator),
                    title: result.item.localizedDisplayName(locale: locale),
                    titleShine: result.item.displayTextShine,
                    titleAccessibilityIdentifier: AccessibilityID.Mystery.corruptionRevealTitle,
                    baseHeight: baseHeight,
                ) {
                    ItemArtwork(item: result.item)
                }
            },
            bodyContent: {
                VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionSpacing) {
                    DetailSection(String(localized: L10n.ui_mysterycorruptioncontent_traits_e0ab4)) {
                        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                            ForEach(Array(result.item.displayedAffixes.enumerated()), id: \.element.id) { index, affix in
                                DetailTraitRow(
                                    title: affix.title,
                                    description: affix.description,
                                    comparisonDescription: comparisonDescription(for: affix),
                                    indicators: result.effects.filter { $0.affects(affix) }.map(\.indicator),
                                    titleShine: result.item.affixShine(at: index, affix: affix),
                                    titlePrefix: affix
                                        .isCorrupted ? String(localized: L10n.ui_mysterycorruptioncontent_corrupted_f79ed) : nil,
                                    titlePrefixShine: affix.isCorrupted ? .corruption : .none,
                                )
                            }
                        }
                    }
                }
            },
        )
        .safeAreaInset(edge: .bottom) {
            MysteryPrimaryFooter(
                title: String(localized: L10n.ui_mysterycorruptioncontent_continue_31fbe),
                accessibilityIdentifier: AccessibilityID.Mystery.corruptionContinueButton,
            ) {
                _ = onFinish()
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.vertical, TrinketDesign.Spacing.medium)
        }
    }

    private func comparisonDescription(for affix: ItemAffix) -> String? {
        if let original = result.originalItem.displayedAffixes.first(where: { $0.id == affix.id }) {
            return original.description
        }
        // Added and replaced affixes start at catalog power before their corruption bump.
        return GameContent.itemAffixDefinition(matching: affix.id)?
            .power(for: result.item.rarity)
            .scaled(by: result.item.baseType.affixPowerMultiplier)
            .description
    }

    private func eyebrow(for item: InventoryItem) -> String {
        let tag = item.isTrinket ? String(localized: L10n.ui_mysterycorruptioncontent_trinket_6faed) : item.rarity.label
        return item.isCorrupted ? String(localized: L10n.ui_mysterycorruptioncontent_1_corrupted_7db4d("\(tag)")) : tag
    }
}

private extension CorruptionEffectSummary {
    func affects(_ affix: ItemAffix) -> Bool {
        switch self {
        case let .addedAffix(title), let .bumpedUp(title), let .bumpedDown(title):
            affix.title == title
        case let .replacedAffix(_, to):
            affix.title == to
        case .upgradedRarity:
            false
        }
    }

    var indicator: DetailChangeIndicator {
        DetailChangeIndicator(icon: icon, tint: tintColor, accessibilityLabel: accessibilityLabel)
    }

    var accessibilityLabel: String {
        switch self {
        case let .addedAffix(title): String(localized: L10n.ui_mysterycorruptioncontent_added_1_7a0c9("\(title)"))
        case let .replacedAffix(from, to): String(localized: L10n.ui_mysterycorruptioncontent_replaced_1_with_2_6ae57("\(from)", "\(to)"))
        case let .bumpedUp(title): String(localized: L10n.ui_mysterycorruptioncontent_empowered_1_45315("\(title)"))
        case let .bumpedDown(title): String(localized: L10n.ui_mysterycorruptioncontent_weakened_1_e7597("\(title)"))
        case .upgradedRarity: String(localized: L10n.ui_mysterycorruptioncontent_upgraded_to_astral_82813)
        }
    }

    var icon: GameIcon {
        switch self {
        case .addedAffix: .system("plus.circle.fill")
        case .replacedAffix: .system("shuffle")
        case .bumpedUp: .system("arrow.up.circle.fill")
        case .bumpedDown: .system("arrow.down.circle.fill")
        case .upgradedRarity: .system("sparkles")
        }
    }

    var tintColor: Color {
        switch self {
        case .addedAffix, .bumpedUp, .upgradedRarity: TrinketDesign.Colors.success
        case .bumpedDown: TrinketDesign.Colors.destructive
        case .replacedAffix: TrinketDesign.Colors.accent
        }
    }
}
