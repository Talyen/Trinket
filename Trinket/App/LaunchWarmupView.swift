import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

struct LaunchWarmupView: View {
    private static let fillDuration: TimeInterval = 1.0

    private static let loadingTerms: [String] = [
        "Preparing your adventure…",
        "Polishing ancient trinkets…",
        "Shuffling the battle deck…",
        "Awakening dungeon monsters…",
        "Brewing health potions…",
        "Gathering mana crystals…",
        "Sharpening rusty blades…",
        "Mapping labyrinth corridors…",
        "Attuning magic relics…",
        "Consulting the oracle…",
        "Enchanting arcane baubles…",
        "Counting monster loot…",
        "Training animal companions…",
        "Building a homestead…",
        "Restocking mystery shops…",
    ]

    @State private var progress: Double = 0
    @State private var currentTermIndex = Int.random(in: 0 ..< Self.loadingTerms.count)

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
            Text("TRINKET")
                .trinketTypography(.screenDisplay)
                .foregroundStyle(TrinketDesign.Colors.accent)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(TrinketDesign.Colors.accent)
                .frame(maxWidth: 240)

            Text(Self.loadingTerms[currentTermIndex])
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .id(currentTermIndex)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .padding(TrinketDesign.Metrics.contentMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("Launch Warmup")
        .task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: Self.fillDuration)) {
                progress = 1
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled else { break }
                withAnimation(TrinketMotion.Content.fade) {
                    var nextIndex = currentTermIndex
                    while nextIndex == currentTermIndex {
                        nextIndex = Int.random(in: 0 ..< Self.loadingTerms.count)
                    }
                    currentTermIndex = nextIndex
                }
            }
        }
    }
}
