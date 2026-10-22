import SwiftUI
import TrinketDesignSystem

struct LaunchWarmupView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLaunchPresentationReady) private var isLaunchPresentationReady
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var loadingStartDate: Date?
    @State private var currentTermIndex = 0
    @State private var loadingArtwork: LaunchLoadingArtwork?
    let isMinimumLoadingTimeComplete: Bool
    let onMinimumLoadingTimeComplete: @MainActor () -> Void

    private static let minimumLoadingDuration: TimeInterval = 2

    private static let loadingTerms: [LocalizedStringResource] = [
        L10n.ui_launchwarmupview_preparing_your_adventure_3154a,
        L10n.ui_launchwarmupview_polishing_ancient_trinkets_b4181,
        L10n.ui_launchwarmupview_shuffling_the_battle_deck_aa39a,
        L10n.ui_launchwarmupview_awakening_dungeon_monsters_a51e6,
        L10n.ui_launchwarmupview_brewing_health_potions_5e1c4,
        L10n.ui_launchwarmupview_gathering_mana_crystals_cb4a8,
        L10n.ui_launchwarmupview_sharpening_rusty_blades_dfa1e,
        L10n.ui_launchwarmupview_mapping_labyrinth_corridors_49adc,
        L10n.ui_launchwarmupview_attuning_magic_relics_c9751,
        L10n.ui_launchwarmupview_consulting_the_oracle_2df6c,
        L10n.ui_launchwarmupview_enchanting_arcane_baubles_40315,
        L10n.ui_launchwarmupview_counting_monster_loot_47d92,
        L10n.ui_launchwarmupview_training_animal_companions_3ec73,
        L10n.ui_launchwarmupview_building_a_homestead_d7fb3,
        L10n.ui_launchwarmupview_restocking_mystery_shops_97e31,
    ]

    private var loadingTitle: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 60.0,
            paused: !isVisible || loadingStartDate == nil || scenePhase != .active || isLaunchPresentationReady
                || (reduceMotion && isMinimumLoadingTimeComplete),
        )) { context in
            let elapsed = loadingStartDate.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            let fill = isMinimumLoadingTimeComplete ? 1 : min(1, elapsed / Self.minimumLoadingDuration)

            Text(L10n.ui_launchwarmupview_trinket_6faed)
                .foregroundStyle(.secondary)
                .overlay {
                    Text(L10n.ui_launchwarmupview_trinket_6faed)
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
                .overlay(alignment: .top) {
                    if let loadingArtwork {
                        LaunchLoadingDecoration(
                            artwork: loadingArtwork,
                            elapsed: isMinimumLoadingTimeComplete ? max(Self.minimumLoadingDuration, elapsed) : elapsed,
                            reduceMotion: reduceMotion,
                        )
                    }
                }
                .accessibilityLabel(Text(L10n.ui_launchwarmupview_loading_trinket_24dee))
        }
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Spacing.medium) {
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
        .task {
            let prepared = await LaunchLoadingArtwork.preparation.value
            guard !Task.isCancelled else { return }
            loadingArtwork = prepared
        }
        .onAppear {
            isVisible = true
            if loadingStartDate == nil {
                loadingStartDate = Date.now
            }
        }
        .onDisappear {
            isVisible = false
            loadingStartDate = nil
        }
        .task(id: loadingStartDate) {
            guard loadingStartDate != nil, !isMinimumLoadingTimeComplete else { return }
            try? await Task.sleep(for: .seconds(Self.minimumLoadingDuration))
            guard !Task.isCancelled else { return }
            onMinimumLoadingTimeComplete()
        }
        .task(id: loadingStartDate) {
            guard loadingStartDate != nil, !isMinimumLoadingTimeComplete else { return }
            while !Task.isCancelled, !isMinimumLoadingTimeComplete {
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled, !isMinimumLoadingTimeComplete else { break }
                withAnimation(TrinketMotion.Content.fade) {
                    currentTermIndex = (currentTermIndex + 1) % Self.loadingTerms.count
                }
            }
        }
    }
}
