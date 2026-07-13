import SwiftUI
import TrinketCore

struct TrinketRarityPresentation: Equatable, Sendable {
    let label: String
    let isPremium: Bool

    init(rarity: Rarity) {
        label = rarity.label.uppercased()
        isPremium = rarity == .astral
    }
}

public struct TrinketRarityLabel: View {
    private let presentation: TrinketRarityPresentation

    @State private var shinePhase = false

    public init(rarity: Rarity) {
        presentation = TrinketRarityPresentation(rarity: rarity)
    }

    public var body: some View {
        Group {
            if presentation.isPremium {
                premiumLabel
            } else {
                Text(presentation.label)
                    .foregroundStyle(.secondary)
            }
        }
        .trinketTypography(.eyebrow)
    }

    private var premiumLabel: some View {
        Text(presentation.label)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        TrinketDesign.Colors.arcane,
                        TrinketDesign.Colors.informational,
                        TrinketDesign.Colors.Overlay.paper,
                        TrinketDesign.Colors.arcane
                    ],
                    startPoint: UnitPoint(x: shinePhase ? 1.35 : -0.35, y: 0.5),
                    endPoint: UnitPoint(x: shinePhase ? 2.35 : 0.65, y: 0.5)
                )
            )
            .shadow(color: TrinketDesign.Colors.arcane.opacity(0.62), radius: 6)
            .onAppear {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    shinePhase = true
                }
            }
            .onDisappear {
                shinePhase = false
            }
    }
}
