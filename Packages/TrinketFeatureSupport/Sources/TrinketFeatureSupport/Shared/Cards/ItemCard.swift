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
    /// When false, art is clipped only — no panel fill/stroke/shadow (shop offer tiles).
    var appliesCardSurface: Bool = true
    var isSelected = false
    /// Fades the label out over the battle dissolve window (salvage removal).
    var fadesLabel = false
    var customShineKeywords: [Keyword]?
    /// Color-driven shine used when no keyword shine applies.
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
        @ViewBuilder art: @escaping () -> Art
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

    private var effectiveShineKeywords: [Keyword]? {
        // Deliberate precedence: caller-supplied keywords win even on Uniques —
        // the equipment slot picker passes equipped affinities so a selected card
        // shows what it grants. Only keyword-less Uniques get the ember border.
        if let customShineKeywords {
            return customShineKeywords
        }
        guard item.rarity != .unique else { return nil }
        if enablesAstralShine {
            return item.astralShineKeywords
        }
        return nil
    }

    private var effectiveShineColors: [Color]? {
        if item.rarity == .unique {
            return UniqueShine.borderColors
        }
        return effectiveShineKeywords == nil ? customShineColors : nil
    }

    public var body: some View {
        ProductCardShell(
            isSelected: isSelected,
            appliesCardSurface: appliesCardSurface,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
            shineKeywords: effectiveShineKeywords,
            shineColors: effectiveShineColors,
            shineLineWidth: shineLineWidth,
            art: art,
            label: {
                switch presentation {
                case .standard:
                    standardLabel
                case .reveal:
                    revealLabel
                }
            }
        )
        .onAppear {
            guard fadesLabel else { return }
            withAnimation(.easeOut(duration: TrinketMotion.Content.cardDissolveDuration)) {
                labelOpacity = 0
            }
        }
    }

    private var standardLabel: some View {
        VStack(spacing: TrinketDesign.Metrics.tightSpacing) {
            HStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                TrinketRarityLabel(rarity: item.rarity)
                    .lineLimit(1)
                if item.isCorrupted {
                    Text("Corrupted")
                        .trinketTypography(.caption)
                        .foregroundStyle(TrinketDesign.Colors.destructive)
                        .lineLimit(1)
                }
            }

            Text(balanced: item.displayName)
                .trinketTypography(.cardLabel)
                .foregroundStyle(.primary)
                .keywordShine(item.astralShineKeywordSet)
                .uniqueShine(if: item.rarity == .unique)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if showsAffixCount {
                Text(item.affixCountLabel)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(labelOpacity)
    }

    private var revealLabel: some View {
        VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            TrinketRarityLabel(rarity: item.rarity)

            Text(balanced: item.displayName)
                .trinketTypography(.sectionDisplay)
                .uniqueShine(if: item.rarity == .unique)
                .multilineTextAlignment(.center)
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
        enablesAstralShine: Bool = true
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
            enablesAstralShine: enablesAstralShine
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
