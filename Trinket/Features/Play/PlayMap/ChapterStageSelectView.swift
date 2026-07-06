import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var partyPicker: PartyPickerKind?
    @State private var heroOverscroll: CGFloat = 0

    let onStageTap: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ChapterJourneyHero(
                        chapter: appState.playChapter,
                        overscroll: heroOverscroll
                    )

                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(journeyRows) { row in
                            rowView(row)
                                .id(row.id)
                                .modifier(JourneyScrollTransition(isEnabled: !reduceMotion))
                        }
                    }
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .trinketScreenBackground(.playJourney)
            .accessibilityIdentifier(AccessibilityID.Screen.play)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                HeroHeaderLayout.overscroll(
                    contentOffsetY: geometry.contentOffset.y,
                    topInset: geometry.contentInsets.top
                )
            } action: { _, overscroll in
                heroOverscroll = overscroll
            }
            .onAppear {
                scrollToInitialTarget(with: proxy)
                updateMusicPreview()
            }
            .onChange(of: appState.journey.current) { _, _ in
                updateMusicPreview()
            }
            .onDisappear {
                appState.battle.setMusicPreview(for: nil)
            }
            .onChange(of: appState.sessionState.mapScrollNonce) { _, _ in
                guard let targetID = appState.sessionState.mapScrollStageID else { return }
                withAnimation(scrollAnimation) {
                    proxy.scrollTo(targetID, anchor: .center)
                }
            }
            .sheet(item: $partyPicker) { picker in
                PartyPickerSheet(
                    kind: picker,
                    combatants: combatants(for: picker),
                    onSelect: { combatant in
                        select(combatant, for: picker)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .trinketScreenBackground(.playJourney)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }

    private var journeyRows: [ChapterJourneyRow] {
        JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: appState.playChapter,
            progress: appState.journey.current
        )
    }

    @ViewBuilder
    private func rowView(_ row: ChapterJourneyRow) -> some View {
        switch row {
        case let .stage(stage, state):
            JourneyStageRow(
                stage: stage,
                state: state,
                activeHero: appState.roster.activeHero,
                activePet: appState.roster.activePet,
                onHeroPicker: { partyPicker = .hero },
                onPetPicker: { partyPicker = .pet },
                onEnemyTap: { onEnemyTap(stage) },
                onPrimaryAction: { onStageTap(stage) }
            )
        case let .chapterGate(chapter):
            JourneyChapterGate(chapter: chapter)
        }
    }

    private func scrollToInitialTarget(with proxy: ScrollViewProxy) {
        guard let target = resolvedScrollTargetID() else { return }

        DispatchQueue.main.async {
            withAnimation(scrollAnimation) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func resolvedScrollTargetID() -> String? {
        if let saved = appState.sessionState.mapScrollStageID,
           AppState.shouldRestoreMapScroll(saved, journey: appState.journey.current) {
            return saved
        }
        return JourneyMapPresentation.scrollFocusID(
            for: appState.journey.current,
            chapter: appState.playChapter,
            chapters: GameContent.chapters
        )
    }

    private var activeStage: Stage? {
        guard let stageID = appState.journey.current.activeStageID else { return nil }
        return GameContent.stage(id: stageID)
    }

    private func updateMusicPreview() {
        appState.battle.setMusicPreview(for: activeStage)
    }

    private var scrollAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.42, extraBounce: 0.04)
    }

    private func combatants(for picker: PartyPickerKind) -> [Combatant] {
        switch picker {
        case .hero:
            return appState.roster.heroes
        case .pet:
            return appState.roster.pets
        }
    }

    private func select(_ combatant: Combatant, for picker: PartyPickerKind) {
        var updatedRoster = appState.roster.current
        switch picker {
        case .hero:
            updatedRoster.setActiveHero(combatant)
        case .pet:
            updatedRoster.setActivePet(combatant)
        }
        appState.roster.current = updatedRoster
    }
}
