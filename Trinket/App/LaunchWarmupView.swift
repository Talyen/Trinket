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

    private var loadingBar: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 60.0,
            paused: !isVisible || loadingStartDate == nil || scenePhase != .active || isLaunchPresentationReady
                || (reduceMotion && isMinimumLoadingTimeComplete),
        )) { context in
            let elapsed = loadingStartDate.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            let fill = isMinimumLoadingTimeComplete ? 1 : min(1, elapsed / Self.minimumLoadingDuration)

            Capsule()
                .fill(TrinketDesign.Colors.accent.opacity(0.18))
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        Capsule()
                            .fill(TrinketDesign.Colors.accent)
                            .frame(width: geometry.size.width * fill)
                    }
                }
                .frame(height: 10)
                .overlay(alignment: .top) {
                    if let loadingArtwork {
                        LaunchLoadingDecoration(
                            artwork: loadingArtwork,
                            elapsed: isMinimumLoadingTimeComplete ? max(Self.minimumLoadingDuration, elapsed) : elapsed,
                            reduceMotion: reduceMotion,
                        )
                    }
                }
                .accessibilityHidden(true)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            // The Ambush canvas has transparent side gutters. Size the visible mark to about 94% of phone width.
            let logoWidth = min(size.width * 1.14, size.height * 0.78, 740)
            let logoHeight = logoWidth * 2 / 3
            let logoCenter = size.height * 0.39
            let logoBottom = logoCenter + logoHeight / 2
            let barCenter = (logoBottom + size.height + geometry.safeAreaInsets.bottom) / 2

            ZStack {
                Group {
                    if let loadingArtwork {
                        Image(decorative: loadingArtwork.logo, scale: 3)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: logoWidth, height: logoHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(L10n.ui_launchwarmupview_loading_trinket_24dee))
                .position(x: size.width / 2, y: logoCenter)

                loadingBar
                    .frame(width: min(size.width * 0.78, 380))
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .top) {
                        Text(Self.loadingTerms[currentTermIndex])
                            .trinketTypography(.rowTitle)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 22)
                            .contentTransition(.opacity)
                    }
                    .position(x: size.width / 2, y: barCenter)
            }
        }
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
