import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Cinematic Campaign chapter overview with five stable, inline stage rows.
struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onStageTap: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void

    @State private var selectedChapterID: String?
    @State private var expandedStageID: String?

    var body: some View {
        DetailHeroScrollShell(
            title: selectedChapter.title,
            backgroundMode: .playJourney,
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            ChapterJourneyHero(
                chapter: selectedChapter,
                availableChapters: availableChapters,
                baseHeight: baseHeight,
                overscroll: overscroll,
                onSelectChapter: selectChapter
            )
        } bodyContent: {
            ChapterStageList(
                rows: stageRows,
                expandedStageID: expandedStageID,
                onToggleExpansion: toggleExpansion,
                onEnemyTap: onEnemyTap,
                onPrimaryAction: handlePrimaryAction
            )
            .padding(.bottom, 92)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.play)
        .overlay(alignment: .topLeading) {
            Text("Chapter \(selectedChapter.number)")
                .accessibilityIdentifier(
                    AccessibilityID.Play.chapterHeader(number: selectedChapter.number)
                )
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(false)
        }
        .onAppear {
            synchronizeSelection(forceCurrentChapter: selectedChapterID == nil)
            updateMusicPreview()
        }
        .onChange(of: appState.journey.current) { _, _ in
            synchronizeSelection(forceCurrentChapter: true)
            updateMusicPreview()
        }
        .onDisappear {
            appState.battle.setMusicPreview(for: nil)
        }
    }

    private var selectedChapter: Chapter {
        if let selectedChapterID,
           let chapter = GameContent.chapter(id: selectedChapterID),
           availableChapters.contains(where: { $0.id == chapter.id }) {
            return chapter
        }
        return appState.playChapter
    }

    private var availableChapters: [Chapter] {
        let activeIndex = GameContent.chapters.firstIndex {
            $0.id == appState.journey.current.activeChapterID
        } ?? GameContent.chapters.startIndex
        return Array(GameContent.chapters.prefix(through: activeIndex))
    }

    private var stageRows: [ChapterStageRowPresentation] {
        ChapterStageRowPresentation.rows(
            for: selectedChapter,
            progress: appState.journey.current
        )
    }

    private func selectChapter(_ chapter: Chapter) {
        withAnimation(stageAnimation) {
            selectedChapterID = chapter.id
            expandedStageID = chapter.id == appState.journey.current.activeChapterID
                ? appState.journey.current.activeStageID
                : nil
        }
    }

    private func toggleExpansion(_ stage: Stage) {
        guard appState.journey.current.isActive(stage) else { return }
        withAnimation(stageAnimation) {
            expandedStageID = expandedStageID == stage.id ? nil : stage.id
        }
    }

    private func handlePrimaryAction(_ stage: Stage) {
        guard appState.journey.current.isActive(stage) else { return }
        onStageTap(stage)
    }

    private func synchronizeSelection(forceCurrentChapter: Bool) {
        let activeChapter = appState.playChapter
        if forceCurrentChapter || selectedChapterID == nil {
            selectedChapterID = activeChapter.id
        }
        expandedStageID = selectedChapterID == activeChapter.id
            ? appState.journey.current.activeStageID
            : nil
    }

    private func updateMusicPreview() {
        let activeStage = appState.journey.current.activeStageID.flatMap(GameContent.stage(id:))
        appState.battle.setMusicPreview(for: activeStage)
    }

    private var stageAnimation: Animation {
        reduceMotion ? TrinketMotion.Journey.reduceMotion : TrinketMotion.Journey.stageExpansion
    }
}

private struct ChapterJourneyHero: View {
    let chapter: Chapter
    let availableChapters: [Chapter]
    let baseHeight: CGFloat
    let overscroll: CGFloat
    let onSelectChapter: (Chapter) -> Void

    private var art: BackgroundArtReference? {
        ArtCatalog.backgroundArtByID[chapter.id]
            ?? ArtCatalog.backgroundArtByID["chapter-1"]
    }

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .bottomLeading
        ) {
            if let art {
                Image(art.imageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
                chapter.theme.tint
                    .accessibilityLabel("\(chapter.title) chapter artwork")
            }
        } overlay: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.22), Color.black.opacity(0.94)],
                    startPoint: .init(x: 0.5, y: 0.35),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        ForEach(availableChapters) { availableChapter in
                            Button {
                                onSelectChapter(availableChapter)
                            } label: {
                                if availableChapter.id == chapter.id {
                                    Label(
                                        "Chapter \(availableChapter.number)",
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text("Chapter \(availableChapter.number)")
                                }
                            }
                        }
                    } label: {
                        Label("Chapter \(chapter.number)", systemImage: "chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .labelStyle(ChapterMenuLabelStyle())
                    }
                    .trinketGlassChip(.compact)
                    .accessibilityIdentifier(AccessibilityID.Play.chapterPicker)
                    .accessibilityLabel("Chapter \(chapter.number), choose chapter")

                    Text(chapter.title)
                        .trinketTypography(.screenDisplay)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.95), radius: 1, y: 1)
                        .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                        .accessibilityIdentifier(
                            AccessibilityID.Play.chapterTitle(number: chapter.number)
                        )
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.bottom, 16)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ChapterMenuLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
                .font(.caption.weight(.bold))
        }
    }
}
