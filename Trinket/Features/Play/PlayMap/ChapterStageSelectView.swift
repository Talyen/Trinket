import SwiftUI

struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var partyPicker: PartyPickerKind?

    let chapter: Chapter
    let progress: JourneyProgressState
    let onStageTap: (Stage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ChapterJourneyHero(chapter: chapter)

                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            VStack(spacing: 14) {
                                ForEach(presentation.rows) { row in
                                    rowView(row)
                                        .id(row.id)
                                        .modifier(JourneyScrollTransition(isEnabled: !reduceMotion))
                                }
                            }
                            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                        } header: {
                            CompactChapterHeader(chapter: chapter)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
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
                    selectedID: selectedID(for: picker),
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
                activeHero: appState.roster.activeHero,
                activePet: appState.roster.activePet,
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
            return appState.roster.heroes
        case .pet:
            return appState.roster.pets
        }
    }

    private func selectedID(for picker: PartyPickerKind) -> String {
        switch picker {
        case .hero:
            return appState.roster.current.activeHeroID
        case .pet:
            return appState.roster.current.activePetID
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

private struct ChapterJourneyHero: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chapter: Chapter

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ChapterArt(chapter: chapter, reduceTransparency: reduceTransparency)
                .visualEffect { content, proxy in
                    let minY = proxy.frame(in: .scrollView).minY
                    let pullDistance = max(minY, 0)
                    return content
                        .scaleEffect(1 + pullDistance / 900)
                        .offset(y: min(minY, 0) * 0.18)
                }

            LinearGradient(
                colors: [.clear, .black.opacity(0.64)],
                startPoint: .center,
                endPoint: .bottom
            )
            .accessibilityHidden(true)

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
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.bottom, 28)
            .accessibilityIdentifier(AccessibilityID.Play.chapterHeader(number: chapter.number))
        }
        .frame(height: 360)
        .frame(maxWidth: .infinity)
        .clipped()
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
    }
}

private struct CompactChapterHeader: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chapter: Chapter

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ChapterArt(chapter: chapter, reduceTransparency: reduceTransparency)
                .saturation(0.88)
                .brightness(-0.06)

            Rectangle()
                .fill(.black.opacity(0.36))
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chapter \(chapter.number)")
                        .font(.caption.weight(.semibold))
                    Text(chapter.title.isEmpty ? "Next Chapter" : chapter.title)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.84))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, 10)
        }
        .frame(height: 68)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter \(chapter.number), \(chapter.title)")
    }
}

private struct ChapterArt: View {
    let chapter: Chapter
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            chapter.theme.tint.opacity(0.22)

            if !reduceTransparency,
               let bgImageName = ArtCatalog.backgroundArtByID[chapter.id]?.imageName {
                Image(bgImageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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

            VStack(alignment: .leading, spacing: 8) {
                StageStatusHeader(stage: stage, state: .active)

                Text(stage.flavorText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
            .accessibilityIdentifier("Stage \(stage.chapterNumber)-\(stage.stageNumber) Node")
            .accessibilityLabel("\(stage.mapLabel), active \(stage.encounter.title)")
            .sensoryFeedback(.selection, trigger: actionFeedbackTrigger)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(stage.encounter.mapTint.opacity(0.42), lineWidth: 1.5)
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

            VStack(alignment: .leading, spacing: 8) {
                StageStatusHeader(stage: stage, state: .future)

                Text(stage.flavorText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground).opacity(0.70), in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Stage \(stage.chapterNumber)-\(stage.stageNumber) Node")
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
        .accessibilityIdentifier("Stage \(stage.chapterNumber)-\(stage.stageNumber) Node")
        .accessibilityLabel("\(stage.mapLabel), complete, \(stage.encounterSubjectName)")
    }
}

private struct StageStatusHeader: View {
    let stage: Stage
    let state: StageNodeState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Label(stage.encounter.title, systemImage: state.symbolName(for: stage))
                .font(.caption.weight(.semibold))
                .foregroundStyle(state.tint(for: stage))
                .labelStyle(.titleAndIcon)

            Spacer(minLength: 8)

            Text(stage.mapLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }

        Text(stage.encounterSubjectName)
            .font(.title3.weight(.bold))
            .foregroundStyle(state == .future ? .secondary : .primary)
            .lineLimit(2)
            .minimumScaleFactor(0.86)
    }
}

private struct EncounterArtwork: View {
    let stage: Stage
    let isLocked: Bool

    var body: some View {
        ZStack {
            if let art = stage.encounterArtReference {
                Image(art.thumbnailImageName ?? art.imageName)
                    .resizable()
                    .scaledToFill()
                    .saturation(isLocked ? 0.48 : 1)
                    .opacity(isLocked ? 0.72 : 1)
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
                stage.encounter.mapTint.opacity(0.14)
                Image(systemName: stage.encounter.symbolName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(stage.encounter.mapTint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }

            if isLocked {
                Rectangle()
                    .fill(.black.opacity(0.22))
                    .accessibilityHidden(true)

                Label("Locked", systemImage: "lock.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.36), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

private struct ActivePartyPickerRow: View {
    let hero: Combatant
    let pet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CompactPartyButton(title: "Hero", combatant: hero, onSelect: onHeroPicker)
            CompactPartyButton(title: "Pet", combatant: pet, onSelect: onPetPicker)
        }
    }
}

private struct CompactPartyButton: View {
    let title: String
    let combatant: Combatant
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                CombatantArtwork(combatant: combatant, variant: .card)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(combatant.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(title) Party Picker")
        .accessibilityLabel("\(title), \(combatant.name)")
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
        .accessibilityIdentifier("Chapter \(chapter.number) Locked")
        .accessibilityLabel("Chapter \(chapter.number), locked")
    }
}

private struct JourneyScrollTransition: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.72)
                    .scaleEffect(phase.isIdentity ? 1 : 0.97)
            }
        } else {
            content
        }
    }
}

private extension StageEncounter {
    var artAspectRatio: CGFloat {
        switch self {
        case .battle:
            return 1
        case .event, .shop, .rest:
            return 4.0 / 3.0
        }
    }
}

private extension StageNodeState {
    func symbolName(for stage: Stage) -> String {
        switch self {
        case .active:
            return stage.encounter.symbolName
        case .completed, .justCompleted:
            return "checkmark.circle.fill"
        case .future:
            return "lock.fill"
        }
    }

    func tint(for stage: Stage) -> Color {
        switch self {
        case .active:
            return stage.encounter.mapTint
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success
        case .future:
            return .secondary
        }
    }
}
