import SwiftUI
import TrinketCore

public struct TrinketRarityLabel: View {
    private let rarity: Rarity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shinePhase = false

    public init(rarity: Rarity) {
        self.rarity = rarity
    }

    public var body: some View {
        Group {
            switch rarity {
            case .astral, .unique:
                premiumLabel
            case .basic:
                Text(rarity.label.uppercased()).foregroundStyle(.secondary)
            }
        }
        .trinketTypography(.eyebrow)
    }

    private var premiumColors: [Color] {
        switch rarity {
        case .astral:
            [
                TrinketDesign.Colors.arcane,
                TrinketDesign.Colors.informational,
                TrinketDesign.Colors.Overlay.paper,
                TrinketDesign.Colors.arcane,
            ]
        case .unique:
            [
                TrinketDesign.Colors.warning,
                TrinketDesign.Colors.warning.opacity(0.55),
                TrinketDesign.Colors.Overlay.paper,
                TrinketDesign.Colors.warning,
            ]
        case .basic:
            []
        }
    }

    private var premiumShadowColor: Color {
        rarity == .astral ? TrinketDesign.Colors.arcane : TrinketDesign.Colors.warning
    }

    private var premiumLabel: some View {
        Text(rarity.label.uppercased())
            .foregroundStyle(
                LinearGradient(
                    colors: premiumColors,
                    startPoint: UnitPoint(x: shinePhase ? 1.35 : -0.35, y: 0.5),
                    endPoint: UnitPoint(x: shinePhase ? 2.35 : 0.65, y: 0.5),
                ),
            )
            .shadow(color: premiumShadowColor.opacity(TrinketDesign.Opacity.glow), radius: 6)
            .task {
                guard !reduceMotion else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(TrinketMotion.Shine.textAnimation) { shinePhase = true }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    shinePhase = false
                } else {
                    withAnimation(TrinketMotion.Shine.textAnimation) { shinePhase = true }
                }
            }
            .onDisappear { shinePhase = false }
    }
}
