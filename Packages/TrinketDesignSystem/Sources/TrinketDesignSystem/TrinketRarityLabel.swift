import SwiftUI
import TrinketCore

public struct TrinketRarityLabel: View {
    private let rarity: Rarity

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
                Text(rarity.label.uppercased())
                    .foregroundStyle(.secondary)
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
                    endPoint: UnitPoint(x: shinePhase ? 2.35 : 0.65, y: 0.5)
                )
            )
            .shadow(color: premiumShadowColor.opacity(0.62), radius: 6)
            .task {
                // Defer shine so Collection/Homestead first paint is not stacked
                // with every premium label's animation commit on the same frame.
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    shinePhase = true
                }
            }
            .onDisappear {
                shinePhase = false
            }
    }
}
