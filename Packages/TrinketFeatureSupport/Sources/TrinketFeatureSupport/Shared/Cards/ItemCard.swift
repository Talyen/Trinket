import SwiftUI
import TrinketContent
import TrinketDesignSystem

public enum ItemCardPresentation {
    case standard
    case reveal
}

public struct ItemCard<Art: View>: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    var presentation: ItemCardPresentation = .standard
    var appliesCardSurface: Bool = true
    var isSelected = false
    var fadesLabel = false
    var shine: Shine?
    var shineLineWidth: CGFloat = 2
    @ViewBuilder private var art: () -> Art

    @State private var labelOpacity = 1.0

    public init(
        item: InventoryItem,
        showsAffixCount: Bool,
        showsName: Bool = true,
        reservesLabelSpace: Bool = true,
        presentation: ItemCardPresentation = .standard,
        appliesCardSurface: Bool = true,
        isSelected: Bool = false,
        fadesLabel: Bool = false,
        shine: Shine? = nil,
        shineLineWidth: CGFloat = 2,
        @ViewBuilder art: @escaping () -> Art,
    ) {
        self.item = item
        self.showsAffixCount = showsAffixCount
        self.showsName = showsName
        self.reservesLabelSpace = reservesLabelSpace
        self.presentation = presentation
        self.appliesCardSurface = appliesCardSurface
        self.isSelected = isSelected
        self.fadesLabel = fadesLabel
        self.shine = shine
        self.shineLineWidth = shineLineWidth
        self.art = art
    }

    private var effectiveShine: Shine {
        if let shine {
            return shine
        }
        if item.rarity == .unique {
            return .unique
        }
        return item.astralShine
    }

    public var body: some View {
        ProductCardShell(
            isSelected: isSelected,
            appliesCardSurface: appliesCardSurface,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
            shine: effectiveShine,
            shineLineWidth: shineLineWidth,
            art: art,
            label: {
                switch presentation {
                case .standard:
                    standardLabel
                case .reveal:
                    revealLabel
                }
            },
        )
        .onAppear {
            guard fadesLabel else { return }
            withAnimation(.easeOut(duration: TrinketMotion.Content.cardDissolveDuration)) {
                labelOpacity = 0
            }
        }
    }

    private var labelShine: Shine {
        if item.rarity == .unique {
            return .unique
        }
        return item.astralShine
    }

    private var standardLabel: some View {
        VStack(spacing: TrinketDesign.Spacing.tight) {
            HStack(spacing: TrinketDesign.Spacing.tight) {
                TrinketRarityLabel(
                    rarity: item.rarity,
                    labelOverride: item.isTrinket ? "Trinket" : nil,
                )
                .trinketFittedText()
                if item.isCorrupted {
                    Text(balanced: "Corrupted")
                        .trinketTypography(.caption)
                        .foregroundStyle(TrinketDesign.Colors.destructive)
                        .trinketFittedText()
                }
            }

            Text(balanced: item.displayName)
                .trinketTypography(.cardLabel)
                .foregroundStyle(.primary)
                .shineText(labelShine)
                .multilineTextAlignment(.center)
                .trinketFittedText()

            if showsAffixCount {
                Text(balanced: item.affixCountLabel)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .trinketFittedText()
            }
        }
        .opacity(labelOpacity)
    }

    private var revealLabel: some View {
        VStack(spacing: TrinketDesign.Spacing.extraSmall) {
            TrinketRarityLabel(
                rarity: item.rarity,
                labelOverride: item.isTrinket ? "Trinket" : nil,
            )

            Text(balanced: item.displayName)
                .trinketTypography(.sectionDisplay)
                .shineText(labelShine)
                .multilineTextAlignment(.center)
                .trinketFittedText()
        }
        .opacity(labelOpacity)
    }
}

public extension ItemCard where Art == ItemArtwork {
    init(
        item: InventoryItem,
        showsAffixCount: Bool,
        showsName: Bool = true,
        reservesLabelSpace: Bool = true,
        presentation: ItemCardPresentation = .standard,
        appliesCardSurface: Bool = true,
        isSelected: Bool = false,
        fadesLabel: Bool = false,
        shine: Shine? = nil,
        shineLineWidth: CGFloat = 2,
    ) {
        self.init(
            item: item,
            showsAffixCount: showsAffixCount,
            showsName: showsName,
            reservesLabelSpace: reservesLabelSpace,
            presentation: presentation,
            appliesCardSurface: appliesCardSurface,
            isSelected: isSelected,
            fadesLabel: fadesLabel,
            shine: shine,
            shineLineWidth: shineLineWidth,
        ) {
            ItemArtwork(item: item, variant: .thumbnail)
        }
    }
}

private extension InventoryItem {
    var affixCountLabel: String {
        "\(affixes.count) \(affixes.count == 1 ? "trait" : "traits")"
    }
}
