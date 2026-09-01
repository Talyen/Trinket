import SwiftUI
import TrinketContent
import TrinketCore
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
    var customShineKeywords: [Keyword]?
    var customShineColors: [Color]?
    var shineLineWidth: CGFloat = 2
    var enablesAstralShine: Bool = true
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
        customShineKeywords: [Keyword]? = nil,
        customShineColors: [Color]? = nil,
        shineLineWidth: CGFloat = 2,
        enablesAstralShine: Bool = true,
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
        self.customShineKeywords = customShineKeywords
        self.customShineColors = customShineColors
        self.shineLineWidth = shineLineWidth
        self.enablesAstralShine = enablesAstralShine
        self.art = art
    }

    private var effectiveShine: Shine {
        if let customShineKeywords {
            return customShineKeywords.isEmpty ? .none : .keywords(customShineKeywords)
        }
        if let customShineColors, !customShineColors.isEmpty {
            return .colors(customShineColors)
        }
        if item.rarity == .unique {
            return .unique
        }
        guard enablesAstralShine, let keywords = item.astralShineKeywords, !keywords.isEmpty else {
            return .none
        }
        return .keywords(keywords)
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
                .keywordShine(item.astralShineKeywordSet)
                .uniqueShine(if: item.rarity == .unique)
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
                .keywordShine(item.astralShineKeywordSet)
                .uniqueShine(if: item.rarity == .unique)
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
        customShineKeywords: [Keyword]? = nil,
        customShineColors: [Color]? = nil,
        shineLineWidth: CGFloat = 2,
        enablesAstralShine: Bool = true,
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
            customShineKeywords: customShineKeywords,
            customShineColors: customShineColors,
            shineLineWidth: shineLineWidth,
            enablesAstralShine: enablesAstralShine,
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
