import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct RewardItemRevealCard: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let item: InventoryItem
    var isCollected: Bool = false

    private var artworkHeight: CGFloat {
        verticalSizeClass == .compact ? 180 : 234
    }

    private var glowColor: Color {
        if let first = item.displayShine.colors?.first {
            return first
        }
        if let firstKeyword = item.plasmaKeywords.first {
            return firstKeyword.visualStyle.color
        }
        return TrinketDesign.Colors.accent
    }

    private var burstColors: [Color] {
        var colors = item.displayShine.colors ?? []
        if colors.isEmpty {
            colors = item.plasmaKeywords.map(\.visualStyle.color)
        }
        if colors.isEmpty {
            colors = [TrinketDesign.Colors.accent]
        }
        colors.append(TrinketDesign.Colors.Overlay.paper)
        return colors
    }

    var body: some View {
        ItemCard(
            item: item,
            showsAffixCount: false,
            presentation: .reveal,
        ) {
            ItemArtwork(item: item)
        }
        .frame(width: artworkHeight * 3.0 / 4.0)
        .frame(maxWidth: .infinity)
        .keyframeAnimator(
            initialValue: RewardCardCollectionValues(),
            trigger: isCollected,
        ) { content, value in
            content
                .scaleEffect(value.scale)
                .overlay {
                    if value.glowOpacity > 0.01 {
                        ZStack {
                            TrinketDesign.cardShape
                                .strokeBorder(glowColor, lineWidth: 3)
                                .blur(radius: 6)
                            TrinketDesign.cardShape
                                .strokeBorder(TrinketDesign.Colors.Overlay.paper, lineWidth: 1.5)
                        }
                        .opacity(value.glowOpacity)
                        .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RewardCollectionBurstView(
                        progress: value.particleProgress,
                        colors: burstColors,
                    )
                }
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(TrinketMotion.Reward.cardCollectionPopScale, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.23, spring: .snappy(duration: 0.23, extraBounce: 0.1))
            }
            KeyframeTrack(\.glowOpacity) {
                LinearKeyframe(1.0, duration: 0.08)
                CubicKeyframe(0.0, duration: 0.27)
            }
            KeyframeTrack(\.particleProgress) {
                LinearKeyframe(0.0, duration: 0.02)
                CubicKeyframe(1.0, duration: 0.33)
            }
        }
    }
}

private struct RewardCardCollectionValues {
    var scale: Double = 1.0
    var glowOpacity: Double = 0.0
    var particleProgress: Double = 0.0
}
