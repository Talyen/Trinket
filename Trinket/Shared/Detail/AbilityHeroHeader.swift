import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityHeroHeader: View {
    let ability: Ability
    let baseHeight: CGFloat
    let overscroll: CGFloat

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .topLeading,
            artworkBlend: .bottom(into: .canvas)
        ) {
            abilityArtwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } overlay: {
            titleBlock
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    @ViewBuilder
    private var abilityArtwork: some View {
        if let artReference = ability.artReference {
            Image.preparedAsset(named: artReference.imageName)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fill)
                .clipped()

        } else {
            placeholderArt
        }
    }

    private var placeholderArt: some View {
        let style = TrinketDesign.CardPlaceholderStyle.ability
        return ZStack {
            style.color.opacity(0.18)

            Image(systemName: style.symbolName)
                .font(.system(size: placeholderIconSize, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            Text(ability.tier.rawValue.uppercased())
                .trinketTypography(.eyebrow)
                .trinketOnArtText(.eyebrow)

            Text(ability.name)
                .trinketTypography(.screenDisplay)
                .trinketOnArtText(.title)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }
}

struct AbilityDetailView: View {
    let ability: Ability
    var primaryActionTitle: String?
    var primaryActionAccessibilityID: String?
    var onPrimaryAction: (() -> Void)?

    init(
        ability: Ability,
        primaryActionTitle: String? = nil,
        primaryActionAccessibilityID: String? = nil,
        onPrimaryAction: (() -> Void)? = nil
    ) {
        self.ability = ability
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionAccessibilityID = primaryActionAccessibilityID
        self.onPrimaryAction = onPrimaryAction
    }

    var body: some View {
        DetailHeroScrollShell(title: ability.name) { baseHeight, overscroll in
            AbilityHeroHeader(
                ability: ability,
                baseHeight: baseHeight,
                overscroll: overscroll
            )
            .accessibilityIdentifier(AccessibilityID.LoadoutPicker.abilityDetail(ability.id))
        } bodyContent: {
            DetailSection(
                "Effect",
                sectionID: AccessibilityID.Battle.abilityDetailEffect
            ) {
                KeywordDescriptionText(text: ability.summary)
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let primaryActionTitle, let onPrimaryAction {
                Button(primaryActionTitle) {
                    onPrimaryAction()
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton()
                .accessibilityIdentifier(primaryActionAccessibilityID ?? primaryActionTitle)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            }
        }
    }
}
