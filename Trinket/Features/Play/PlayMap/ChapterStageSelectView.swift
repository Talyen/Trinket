import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var partyPicker: PartyPickerKind?
    @State private var heroOverscroll: CGFloat = 0
    @State private var scrollPosition: String?

    let onStageTap: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ChapterJourneyHero(
                    chapter: appState.playChapter,
                    overscroll: heroOverscroll
                )

                PlayTabDashboardHeaderView()

                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(journeyRows) { row in
                        rowView(row)
                            .id(row.id)
                            .modifier(JourneyScrollTransition(isEnabled: !reduceMotion))
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollPosition(id: $scrollPosition, anchor: .center)
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
            if let target = resolvedScrollTargetID() {
                applyScrollFocus(target, animated: false)
            }
            updateMusicPreview()
        }
        .onChange(of: appState.journey.current) { _, _ in
            updateMusicPreview()
        }
        .onDisappear {
            appState.battle.setMusicPreview(for: nil)
        }
        .onChange(of: appState.mapScrollFocus) { _, focus in
            guard let focus else { return }
            applyScrollFocus(focus.stageID, animated: true)
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
        .trinketScreenBackground(.playJourney)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }

    private var journeyRows: [ChapterJourneyRow] {
        let rows = JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: appState.playChapter,
            progress: appState.journey.current
        )
        if appState.showResumeBattleCard, let activeStageID = appState.sessionState.activeBattleStageID {
            return rows.filter { row in
                switch row {
                case let .stage(stage, _):
                    return stage.id != activeStageID
                case .chapterGate:
                    return true
                }
            }
        }
        return rows
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

    private func resolvedScrollTargetID() -> String? {
        if let saved = appState.mapScrollStageID,
           AppState.shouldRestoreMapScroll(saved, journey: appState.journey.current) {
            return saved
        }
        return JourneyMapPresentation.scrollFocusID(
            for: appState.journey.current,
            chapter: appState.playChapter,
            chapters: GameContent.chapters
        )
    }

    private func applyScrollFocus(_ stageID: String, animated: Bool) {
        let assignPosition = {
            if scrollPosition == stageID {
                scrollPosition = nil
                Task { @MainActor in
                    scrollPosition = stageID
                }
            } else {
                scrollPosition = stageID
            }
        }

        if animated, let scrollAnimation {
            withAnimation(scrollAnimation, assignPosition)
        } else {
            assignPosition()
        }
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
