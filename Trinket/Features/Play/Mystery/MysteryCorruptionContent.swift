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

    @State private var detailItem: InventoryItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Text("Corrupted")
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(AccessibilityID.Mystery.corruptionRevealTitle)

                    Text("The altar remade your \(result.item.displayName).")
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                comparisonCards

                DetailSection("What Changed") {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(Array(result.effects.enumerated()), id: \.offset) { _, effect in
                            changeRow(effect)
                        }
                    }
                }

                DetailSection("Traits") {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(Array(result.item.displayedAffixes.enumerated()), id: \.element.id) { _, affix in
                            DetailTraitRow(
                                title: affix.title,
                                description: affix.description,
                                titleShineColors: affix.isCorrupted ? CorruptionShine.textColors : nil
                            )
                        }
                    }
                }

                mysteryPersistFailureBanner(session.persistFailureMessage)

                Button("Continue") {
                    _ = onFinish()
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: AccessibilityID.Mystery.corruptionContinueButton
                )
                .trinketCenteredPrimaryAction()
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
        .sheet(item: $detailItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .trinketDetailSheet()
        }
    }

    private var comparisonCards: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.mediumSpacing) {
            comparisonCard(
                label: "BEFORE",
                item: result.originalItem,
                accessibilityID: AccessibilityID.Mystery.corruptionBeforeCard(
                    itemID: result.originalItem.id
                )
            )

            comparisonCard(
                label: "AFTER",
                item: result.item,
                showsCorruptionShine: true,
                accessibilityID: AccessibilityID.Mystery.corruptionAfterCard(
                    itemID: result.item.id
                )
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func comparisonCard(
        label: String,
        item: InventoryItem,
        showsCorruptionShine: Bool = false,
        accessibilityID: String
    ) -> some View {
        Button {
            detailItem = item
        } label: {
            VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                ItemArtwork(item: item)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(TrinketDesign.cardShape)
                    .trinketCardSurface()
                    .colorShineBorder(
                        colors: showsCorruptionShine ? CorruptionShine.borderColors : nil,
                        cornerRadius: TrinketDesign.Corners.card
                    )

                VStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                    Text(label)
                        .trinketTypography(.eyebrow)
                        .foregroundStyle(showsCorruptionShine ? TrinketDesign.Colors.destructive : .secondary)

                    Text(balanced: item.displayName)
                        .trinketTypography(.badge)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.rarity.label.uppercased() + (item.isCorrupted ? " · CORRUPTED" : ""))
                        .trinketTypography(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityIdentifier(accessibilityID)
    }

    private func changeRow(_ effect: CorruptionEffectSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Metrics.smallSpacing) {
            Image(systemName: effect.symbolName)
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
        case let .addedAffix(title):
            "Gained \(title)"
        case let .replacedAffix(from, to):
            "Remade \(from) into \(to)"
        case let .bumpedUp(affixTitle):
            "Empowered \(affixTitle)"
        case let .bumpedDown(affixTitle):
            "Weakened \(affixTitle)"
        case .upgradedRarity:
            "Rose to Astral rarity"
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
