import SwiftUI

struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var partyPicker: PartyPickerKind?

    private let scrollCoordinateSpaceName = "ChapterJourneyScroll"

    let chapter: Chapter
    let progress: JourneyProgressState
    let activeHero: Combatant
    let activePet: Combatant
    let heroes: [Combatant]
    let pets: [Combatant]
    let onStageTap: (Stage) -> Void
    let onSetActiveHero: (Combatant) -> Void
    let onSetActivePet: (Combatant) -> Void

    init(
        chapter: Chapter,
        progress: JourneyProgressState,
        activeHero: Combatant,
        activePet: Combatant,
        heroes: [Combatant],
        pets: [Combatant],
        onStageTap: @escaping (Stage) -> Void,
        onSetActiveHero: @escaping (Combatant) -> Void,
        onSetActivePet: @escaping (Combatant) -> Void
    ) {
        self.chapter = chapter
        self.progress = progress
        self.activeHero = activeHero
        self.activePet = activePet
        self.heroes = heroes
        self.pets = pets
        self.onStageTap = onStageTap
        self.onSetActiveHero = onSetActiveHero
        self.onSetActivePet = onSetActivePet
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ChapterJourneyHero(
                        chapter: chapter,
                        coordinateSpaceName: scrollCoordinateSpaceName
                    )

                    LazyVStack(alignment: .leading, spacing: 24) {
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
            .coordinateSpace(name: scrollCoordinateSpaceName)
            .ignoresSafeArea(edges: .top)
            .background(TrinketDesign.Colors.appBackground)
            .accessibilityIdentifier(AccessibilityID.Screen.play)
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
            chapter: chapter,
            progress: progress
        )
    }

    @ViewBuilder
    private func rowView(_ row: ChapterJourneyRow) -> some View {
        switch row {
        case let .stage(node):
            JourneyStageRow(
                node: node,
                activeHero: activeHero,
                activePet: activePet,
                onHeroPicker: { partyPicker = .hero },
                onPetPicker: { partyPicker = .pet },
                onPrimaryAction: { onStageTap(node.stage) }
            )
        case let .chapterGate(chapter):
            JourneyChapterGate(chapter: chapter)
        }
    }

    private func scrollToInitialTarget(with proxy: ScrollViewProxy) {
        guard let target = presentation.scrollTargetID,
              target != chapter.stages.first?.id
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
            return heroes
        case .pet:
            return pets
        }
    }

    private func select(_ combatant: Combatant, for picker: PartyPickerKind) {
        switch picker {
        case .hero:
            onSetActiveHero(combatant)
        case .pet:
            onSetActivePet(combatant)
        }
    }
}

private struct ChapterJourneyHero: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chapter: Chapter
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { geometry in
            let baseHeight = max(480, geometry.size.height * 0.70)

            OverscrollHeroContainer(
                baseHeight: baseHeight,
                coordinateSpaceName: coordinateSpaceName
            ) {
                ChapterArt(chapter: chapter, reduceTransparency: reduceTransparency)
            } overlay: {
                ZStack(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Chapter \(chapter.number)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.84))

                        Text(chapter.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .shadow(color: .black.opacity(0.48), radius: 8, y: 2)
                    .accessibilityIdentifier(AccessibilityID.Play.chapterHeader(number: chapter.number))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { length, _ in
            max(480, length * 0.70)
        }
        .clipped()
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
    }
}

private struct JourneyStageRow: View {
    let node: VisibleStageNode
    let activeHero: Combatant
    let activePet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void
    let onPrimaryAction: () -> Void

    var body: some View {
        switch node.state {
        case .completed, .justCompleted:
            CompletedStageRow(stage: node.stage)
        case .active:
            ActiveStageCard(
                stage: node.stage,
                activeHero: activeHero,
                activePet: activePet,
                onHeroPicker: onHeroPicker,
                onPetPicker: onPetPicker,
                onPrimaryAction: onPrimaryAction
            )
        case .future:
            LockedStageCard(stage: node.stage)
        }
    }
}

private struct ActiveStageCard: View {
    let stage: Stage
    let activeHero: Combatant
    let activePet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void
    let onPrimaryAction: () -> Void

    @State private var actionFeedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EncounterArtwork(stage: stage, isLocked: false)
                .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
                .clipShape(TrinketDesign.cardShape)

            StageStatusHeader(stage: stage, state: .active)

            ActivePartyPickerRow(
                hero: activeHero,
                pet: activePet,
                onHeroPicker: onHeroPicker,
                onPetPicker: onPetPicker
            )

            Button {
                actionFeedbackTrigger += 1
                onPrimaryAction()
            } label: {
                Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .tint(stage.encounter.mapTint)
            .accessibilityIdentifier(StageMapID.stageNode(for: stage))
            .accessibilityLabel("\(stage.mapLabel), active \(stage.encounter.title)")
            .sensoryFeedback(.selection, trigger: actionFeedbackTrigger)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }
}

private struct LockedStageCard: View {
    let stage: Stage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EncounterArtwork(stage: stage, isLocked: true)
                .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
                .clipShape(TrinketDesign.cardShape)

            StageStatusHeader(stage: stage, state: .future)
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground).opacity(0.70), in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.stageNode(for: stage))
        .accessibilityLabel("\(stage.mapLabel), locked \(stage.encounter.title), \(stage.encounterSubjectName)")
    }
}

private struct CompletedStageRow: View {
    let stage: Stage

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(TrinketDesign.Colors.success.opacity(0.12))

                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.mapLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(stage.encounterSubjectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("Cleared")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TrinketDesign.Colors.success)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground).opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.stageNode(for: stage))
        .accessibilityLabel("\(stage.mapLabel), complete, \(stage.encounterSubjectName)")
    }
}

private struct JourneyChapterGate: View {
    let chapter: Chapter

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ChapterArt(chapter: chapter, reduceTransparency: false)

            LinearGradient(
                colors: [.clear, .black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Locked", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text("Chapter \(chapter.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text(chapter.title.isEmpty ? "Next Chapter" : chapter.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.chapterLocked(chapter))
        .accessibilityLabel("Chapter \(chapter.number), locked")
    }
}
