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
                        ForEach(presentation.rows) { row in
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
            .background(TrinketDesign.Colors.appBackground)
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
            }
            .onChange(of: appState.journey.mapScrollRequest?.id) { _, _ in
                guard let request = appState.journey.mapScrollRequest else { return }
                withAnimation(scrollAnimation) {
                    proxy.scrollTo(request.targetID, anchor: .center)
                }
                appState.journey.clearMapScrollRequest(request)
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
        .background(TrinketDesign.Colors.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }

    private var presentation: ChapterJourneyPresentation {
        ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: appState.playChapter,
            progress: appState.journey.current
        )
    }

    @ViewBuilder
    private func rowView(_ row: ChapterJourneyRow) -> some View {
        switch row {
        case let .stage(node):
            JourneyStageRow(
                node: node,
                activeHero: appState.roster.activeHero,
                activePet: appState.roster.activePet,
                onHeroPicker: { partyPicker = .hero },
                onPetPicker: { partyPicker = .pet },
                onEnemyTap: { onEnemyTap(node.stage) },
                onPrimaryAction: { onStageTap(node.stage) }
            )
        case let .chapterGate(chapter):
            JourneyChapterGate(chapter: chapter)
        }
    }

    private func scrollToInitialTarget(with proxy: ScrollViewProxy) {
        guard let target = presentation.scrollTargetID,
              target != appState.playChapter.stages.first?.id
        else { return }

        DispatchQueue.main.async {
            withAnimation(scrollAnimation) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
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
        switch picker {
        case .hero:
            appState.roster.setActiveHero(combatant)
        case .pet:
            appState.roster.setActivePet(combatant)
        }
    }
}
