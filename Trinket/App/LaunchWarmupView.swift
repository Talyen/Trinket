import SwiftUI
import TrinketDesignSystem

struct LaunchWarmupView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLaunchPresentationReady) private var isLaunchPresentationReady
    @State private var isVisible = false
    @State private var loadingStartDate: Date?
    @State private var currentTermIndex = 0
    @State private var isMinimumTimeComplete = false

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

    private var loadingTitle: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: !isVisible || loadingStartDate == nil || scenePhase != .active || isLaunchPresentationReady,
        )) { context in
            let elapsed = loadingStartDate.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            let fill = isMinimumTimeComplete ? 1 : min(1, elapsed / Self.minimumLoadingDuration)
            let scale = isLaunchPresentationReady ? 1 : 1 + 0.01 * (1 - cos(elapsed * .pi * 2 / 2.4))

            Text("TRINKET")
                .foregroundStyle(.secondary)
                .overlay {
                    Text("TRINKET")
                        .foregroundStyle(TrinketDesign.Colors.accent)
                        .mask(alignment: .leading) {
                            GeometryReader { geometry in
                                Rectangle()
                                    .frame(width: geometry.size.width * fill)
                            }
                        }
                        .accessibilityHidden(true)
                }
                .trinketTypography(.screenDisplay)
                .scaleEffect(scale)
                .accessibilityLabel("Loading Trinket")
        }
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Layout.sectionSpacing) {
            loadingTitle

            Text(Self.loadingTerms[currentTermIndex])
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
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
            isMinimumTimeComplete = false
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
            isMinimumTimeComplete = true
            onMinimumLoadingTimeComplete()
        }
        .task(id: loadingStartDate) {
            guard loadingStartDate != nil else { return }
            while !Task.isCancelled, !isMinimumTimeComplete {
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled, !isMinimumTimeComplete else { break }
                withAnimation(TrinketMotion.Content.fade) {
                    currentTermIndex = (currentTermIndex + 1) % Self.loadingTerms.count
                }
            }
        }
    }
}
