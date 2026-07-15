import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Caster-anchored Skill (or enemy Ultimate) ability-art callout.
struct SkillCalloutView: View {
    let callout: SkillCalloutPresentation
    var body: some View {
        KeyframeAnimator(
            initialValue: SkillCalloutAnimationState(),
            trigger: callout.id
        ) { state in
            calloutCard
                .scaleEffect(state.scale)
                .opacity(state.opacity)
                .offset(y: state.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.08, duration: TrinketMotion.Battle.skillCalloutIn)
                SpringKeyframe(1.0, duration: TrinketMotion.Battle.skillCalloutHold)
                SpringKeyframe(0.96, duration: TrinketMotion.Battle.skillCalloutOut)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1.0, duration: TrinketMotion.Battle.skillCalloutIn)
                CubicKeyframe(1.0, duration: TrinketMotion.Battle.skillCalloutHold)
                CubicKeyframe(0.0, duration: TrinketMotion.Battle.skillCalloutOut)
            }
            KeyframeTrack(\.offsetY) {
                SpringKeyframe(-6, duration: TrinketMotion.Battle.skillCalloutIn)
                SpringKeyframe(-10, duration: TrinketMotion.Battle.skillCalloutHold)
                SpringKeyframe(-14, duration: TrinketMotion.Battle.skillCalloutOut)
            }
        }
        .accessibilityIdentifier("Skill Callout \(callout.abilityName)")
    }

    private var calloutCard: some View {
        let ability = AbilityCatalog.ability(id: callout.abilityID)
        let style = callout.keyword.visualStyle

        return VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let artRef = ability?.artReference {
                        Image.preparedAsset(named: artRef.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(TrinketDesign.cardShape)
                    } else {
                        ZStack {
                            TrinketDesign.cardShape
                                .fill(TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.22))
                            Image(systemName: callout.keyword.visualStyle.symbolName)
                                .trinketTypography(.sectionTitle)
                                .foregroundStyle(style.color)
                        }
                    }
                }
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(style.color.opacity(0.85), lineWidth: 2)
                }
                .trinketCardSurface()
                .shadow(color: style.color.opacity(0.35), radius: 8, y: 2)

            Text(callout.abilityName)
                .trinketTypography(.badge)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .trinketGlassChip(.utility)
        }
        .frame(maxWidth: 96)
    }
}

private struct SkillCalloutAnimationState {
    var opacity = 0.0
    var scale = 0.86
    var offsetY = 0.0
}
