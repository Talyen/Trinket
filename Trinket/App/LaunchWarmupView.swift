import SwiftUI
import TrinketDesignSystem

struct LaunchWarmupView: View {
    @State private var isVisible = false
    @State private var loadingStartDate: Date?
    @State private var currentTermIndex = 0

    let onMinimumLoadingTimeComplete: () -> Void

    private static let minimumLoadingDuration: TimeInterval = 2

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

            Group {
                if let loadingStartDate {
                    ProgressView(
                        timerInterval: loadingStartDate ... loadingStartDate.addingTimeInterval(Self.minimumLoadingDuration),
                        countsDown: false,
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                } else {
                    ProgressView(value: 0)
                }
            }
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
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
            loadingStartDate = nil
        }
        .task(id: isVisible) {
            guard isVisible else { return }
            await Task.yield()
            guard !Task.isCancelled, isVisible, loadingStartDate == nil else { return }
            loadingStartDate = Date.now
        }
        .task(id: loadingStartDate) {
            guard loadingStartDate != nil else { return }
            try? await Task.sleep(for: .seconds(Self.minimumLoadingDuration))
            guard !Task.isCancelled else { return }
            onMinimumLoadingTimeComplete()
        }
        .task(id: loadingStartDate) {
            guard loadingStartDate != nil else { return }
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
