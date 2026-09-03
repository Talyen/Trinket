import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryCorruptionRevealContent: View {
    @Bindable var session: MysteryEncounterSession
    let result: ItemCorruptionResult
    let onFinish: () -> Bool

    var body: some View {
        DetailHeroScrollShell(
            title: result.item.displayName,
            header: { baseHeight in
                DetailHeroHeader(
                    eyebrow: eyebrow(for: result.item),
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
                    Text("The altar remade your \(result.item.displayName).")
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                        .padding(.top, TrinketDesign.Layout.contentTopPadding)

                    if !result.effects.isEmpty {
                        DetailSection("What Changed") {
                            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                                ForEach(Array(result.effects.enumerated()), id: \.offset) { _, effect in
                                    changeRow(effect)
                                }
                            }
                        }
                    }

                    DetailSection("Traits") {
                        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                            ForEach(Array(result.item.displayedAffixes.enumerated()), id: \.element.id) { index, affix in
                                DetailTraitRow(
                                    title: affix.title,
                                    description: affix.description,
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

    private func changeRow(_ effect: CorruptionEffectSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.small) {
            Image(systemName: effect.symbolName)
                // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
                .font(.footnote.weight(.semibold))
                .foregroundStyle(effect.tintColor ?? TrinketDesign.Colors.accent)
                .accessibilityHidden(true)
            Text(effect.displayText)
                .trinketTypography(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension CorruptionEffectSummary {
    var displayText: String {
        switch self {
        case let .addedAffix(title): "Gained \(title)"
        case let .replacedAffix(from, to): "Remade \(from) into \(to)"
        case let .bumpedUp(affixTitle): "Empowered \(affixTitle)"
        case let .bumpedDown(affixTitle): "Weakened \(affixTitle)"
        case .upgradedRarity: "Rose to Astral rarity"
        }
    }

    var symbolName: String {
        switch self {
        case .addedAffix: "plus.circle.fill"
        case .replacedAffix: "arrow.triangle.swap"
        case .bumpedUp: "arrow.up.circle.fill"
        case .bumpedDown: "arrow.down.circle.fill"
        case .upgradedRarity: "sparkles"
        }
    }

    var tintColor: Color? {
        switch self {
        case .addedAffix, .bumpedUp, .upgradedRarity: TrinketDesign.Colors.success
        case .bumpedDown: TrinketDesign.Colors.destructive
        case .replacedAffix: nil
        }
    }
}
