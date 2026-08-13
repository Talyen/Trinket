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
            if rarity == .astral {
                premiumLabel
            } else {
                Text(rarity.label.uppercased())
                    .foregroundStyle(.secondary)
            }
        }
        .trinketTypography(.eyebrow)
    }

    private var premiumLabel: some View {
        Text(rarity.label.uppercased())
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        TrinketDesign.Colors.arcane,
                        TrinketDesign.Colors.informational,
                        TrinketDesign.Colors.Overlay.paper,
                        TrinketDesign.Colors.arcane,
                    ],
                    startPoint: UnitPoint(x: shinePhase ? 1.35 : -0.35, y: 0.5),
                    endPoint: UnitPoint(x: shinePhase ? 2.35 : 0.65, y: 0.5)
                )
            )
            .shadow(color: TrinketDesign.Colors.arcane.opacity(0.62), radius: 6)
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
