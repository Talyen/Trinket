import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryCorruptionRevealContent: View {
    @Bindable var session: MysteryEncounterSession
    let result: ItemCorruptionDetail
    let onFinish: () -> Bool

    var body: some View {
        DetailHeroScrollShell(
            title: result.item.displayName,
            header: { baseHeight in
                DetailHeroHeader(
                    eyebrow: eyebrow(for: result.item),
                    eyebrowIndicators: result.effects.filter { $0 == .upgradedRarity }.map(\.indicator),
                    title: result.item.displayName,
                    titleShine: result.item.displayShine,
                    titleAccessibilityIdentifier: AccessibilityID.Mystery.corruptionRevealTitle,
                    baseHeight: baseHeight,
                ) {
                    ItemArtwork(item: result.item)
                }
            },
            bodyContent: {
                VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionSpacing) {
                    DetailSection("Traits") {
                        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                            ForEach(Array(result.item.displayedAffixes.enumerated()), id: \.element.id) { index, affix in
                                DetailTraitRow(
                                    title: affix.title,
                                    description: affix.description,
                                    indicators: result.effects.filter { $0.affects(affix) }.map(\.indicator),
                                    titleShine: result.item.affixShine(at: index, affix: affix),
                                    titlePrefix: affix.isCorrupted ? "Corrupted " : nil,
                                    titlePrefixShine: affix.isCorrupted ? .corruption : .none,
                                )
                            }
                        }
                    }

                    mysteryPersistFailureBanner(session.persistFailureMessage)
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                }
            },
        )
        .safeAreaInset(edge: .bottom) {
            MysteryPrimaryFooter(
                title: "Continue",
                accessibilityIdentifier: AccessibilityID.Mystery.corruptionContinueButton,
            ) {
                _ = onFinish()
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.vertical, TrinketDesign.Spacing.medium)
        }
    }

    private func eyebrow(for item: InventoryItem) -> String {
        let tag = item.isTrinket ? "TRINKET" : item.rarity.label.uppercased()
        return item.isCorrupted ? "\(tag) · CORRUPTED" : tag
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
        case let .addedAffix(title): "Added \(title)"
        case let .replacedAffix(from, to): "Replaced \(from) with \(to)"
        case let .bumpedUp(title): "Empowered \(title)"
        case let .bumpedDown(title): "Weakened \(title)"
        case .upgradedRarity: "Upgraded to Astral"
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
