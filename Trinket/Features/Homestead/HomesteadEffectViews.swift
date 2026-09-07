import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct HomesteadMaterialChip: View {
    let resource: HomesteadResource
    let value: String
    var isShort = false

    var body: some View {
        TrinketCompactResourceChip(value: value, tint: isShort ? TrinketDesign.Colors.destructive : resource.tint) {
            HomesteadResourceArtwork(resource: resource)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resource.displayName)
        .accessibilityValue(value)
    }
}

struct HomesteadEffectDescription: View {
    let tier: HomesteadNodeTier
    var previousTier: HomesteadNodeTier?
    var typography: TypographyRole = .body

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            ForEach(HomesteadEffectComparison.lines(current: previousTier, proposed: tier)) { comparison in
                if let effect = comparison.proposed {
                    effectView(effect, previous: comparison.current?.value)
                } else if let removed = comparison.current {
                    KeywordDescriptionText(text: "\(removed.prefix) \(removed.value) \(removed.suffix)")
                        .strikethrough()
                }
            }
        }
        .trinketTypography(typography)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func effectView(_ effect: HomesteadEffectLine, previous: String?) -> some View {
        if let resource = effect.resource {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TrinketDesign.Spacing.small) {
                    KeywordDescriptionText(text: effect.prefix)
                    resourceValues(effect, resource: resource, previous: previous)
                    KeywordDescriptionText(text: effect.suffix)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                    KeywordDescriptionText(text: effect.prefix)
                    resourceValues(effect, resource: resource, previous: previous)
                    KeywordDescriptionText(text: effect.suffix)
                }
            }
        } else {
            Text(attributedEffect(effect, previous: previous))
        }
    }

    private func resourceValues(_ effect: HomesteadEffectLine, resource: HomesteadResource, previous: String?) -> some View {
        HStack(spacing: TrinketDesign.Spacing.extraSmall) {
            if let previous, previous != effect.value {
                HomesteadMaterialChip(resource: resource, value: previous)
                Text("→")
            }
            HomesteadMaterialChip(resource: resource, value: effect.value)
        }
    }

    private func attributedEffect(_ effect: HomesteadEffectLine, previous: String?) -> AttributedString {
        var text = KeywordDescriptionText.attributedText(for: effect.prefix + " ")
        if let previous, previous != effect.value {
            var before = AttributedString(previous + " → ")
            before.foregroundColor = .secondary
            text += before
        }
        var value = AttributedString(effect.value)
        value.inlinePresentationIntent = .stronglyEmphasized
        value.foregroundColor = .primary
        text += value
        if !effect.suffix.isEmpty {
            text += KeywordDescriptionText.attributedText(for: " " + effect.suffix)
        }
        return text
    }
}
