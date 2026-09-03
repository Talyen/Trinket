import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct LaunchWarmupView: View {
    @State private var cache = PreparedArtworkCache.shared
    @State private var currentTermIndex = 0

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

    var body: some View {
        VStack(spacing: TrinketDesign.Layout.sectionSpacing) {
            Text("TRINKET")
                .trinketTypography(.screenDisplay)
                .foregroundStyle(TrinketDesign.Colors.accent)

            ProgressView(value: cache.progress)
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
        .padding(TrinketDesign.Layout.contentMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("Launch Warmup")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled else { break }
                withAnimation(TrinketMotion.Content.fade) {
                    currentTermIndex = (currentTermIndex + 1) % Self.loadingTerms.count
                }
            }
        }
    }
}
