import SwiftUI

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedStage: Stage?
    @State private var selectedCombatantDetail: CombatantCollectionDetailSelection?
    @State private var stageMessage: StageMapMessage?
    @State private var pendingScrollTarget: String?

    private var chapters: [Chapter] {
        GameContent.chapters
    }

    private var currentChapter: Chapter {
        chapters.first ?? GameContent.chapters[0]
    }

    var body: some View {
        NavigationStack {
            content
        }
        .sheet(item: $selectedStage) { stage in
            StagePreviewSheet(
                stage: stage,
                chapter: chapter(containing: stage),
                onPrimaryAction: { handlePrimaryAction(for: stage) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedCombatantDetail) { selection in
            CombatantCollectionDetailSheet(selection: selection)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        }
        .alert(item: $stageMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
            guard newValue == nil else { return }
            pendingScrollTarget = appState.journey.current.activeStageID ?? "chapter-2-locked"
        }
        .onChange(of: selectedStage?.id) { _, _ in
            updateMusicPreview(for: selectedStage)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let activeBattle = appState.battle.activeBattle {
            BattleView(
                hero: activeBattle.hero,
                pet: activeBattle.pet,
                enemy: activeBattle.enemy,
                heroProgression: activeBattle.heroProgression,
                petProgression: activeBattle.petProgression,
                heroEquipmentLoadout: activeBattle.heroEquipmentLoadout,
                petEquipmentLoadout: activeBattle.petEquipmentLoadout,
                inventoryState: activeBattle.inventoryState,
                stageReward: activeBattle.stageReward,
                rewardItemNames: activeBattle.rewardItemNames,
                isBattlePaused: Binding(
                    get: { appState.battle.isPaused },
                    set: { appState.battle.isPaused = $0 }
                ),
                onEndBattle: {
                    appState.battle.isPaused = false
                    appState.battle.activeBattle = nil
                },
                onRestartBattle: {
                    appState.battle.activeBattle = ActiveBattleConfiguration(
                        stageID: activeBattle.stageID,
                        hero: activeBattle.hero,
                        pet: activeBattle.pet,
                        enemy: activeBattle.enemy,
                        heroProgression: activeBattle.heroProgression,
                        petProgression: activeBattle.petProgression,
                        heroEquipmentLoadout: activeBattle.heroEquipmentLoadout,
                        petEquipmentLoadout: activeBattle.petEquipmentLoadout,
                        inventoryState: activeBattle.inventoryState,
                        stageReward: activeBattle.stageReward,
                        rewardItemNames: activeBattle.rewardItemNames
                    )
                },
                onVictoryContinue: { battleEarnedGold in
                    completeActiveBattle(activeBattle, battleEarnedGold: battleEarnedGold)
                },
                onShowCombatantDetail: { detail in
                    appState.battle.isPaused = true
                    selectedCombatantDetail = CombatantCollectionDetailSelection(battleSnapshot: detail)
                }
            )
            .id(activeBattle.id)
            .navigationBarBackButtonHidden(true)
        } else {
            JourneyMapView(
                chapter: currentChapter,
                progress: appState.journey.current,
                pendingScrollTarget: $pendingScrollTarget,
                onStageTap: handleStageTap
            )
        }
    }

    private func handleStageTap(_ stage: Stage) {
        let progress = appState.journey.current
        if progress.isActive(stage) {
            selectedStage = stage
        }
        // Tapping locked or completed stages does nothing.
    }

    private func handlePrimaryAction(for stage: Stage) {
        switch stage.encounter {
        case let .battle(enemyID):
            startBattle(for: stage, enemyID: enemyID)
        case .event, .shop, .rest:
            completeStage(stage, hero: activeHero, pet: activePet)
            selectedStage = nil
        }
    }

    private func startBattle(for stage: Stage, enemyID: String) {
        guard let enemy = GameContent.enemy(matching: enemyID)?.combatant else {
            stageMessage = StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
            return
        }

        let hero = activeHero
        let pet = activePet
        selectedStage = nil
        appState.battle.preview = nil
        let rewardItemNames = stage.rewards.itemTemplateIDs.compactMap { templateID in
            GameContent.itemTemplate(matching: templateID)?.displayName
        }
        appState.battle.activeBattle = ActiveBattleConfiguration(
            stageID: stage.id,
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroProgression: appState.roster.current.progression(for: hero),
            petProgression: appState.roster.current.progression(for: pet),
            heroEquipmentLoadout: appState.roster.current.equipmentLoadout(for: hero),
            petEquipmentLoadout: appState.roster.current.equipmentLoadout(for: pet),
            inventoryState: appState.inventory.current,
            stageReward: stage.rewards,
            rewardItemNames: rewardItemNames
        )
    }

    private func completeActiveBattle(_ battle: ActiveBattleConfiguration, battleEarnedGold: Int) {
        if let stageID = battle.stageID,
           let stage = chapters.flatMap(\.stages).first(where: { $0.id == stageID }) {
            completeStage(stage, hero: battle.hero, pet: battle.pet, battleEarnedGold: battleEarnedGold)
        } else if battleEarnedGold > 0 {
            var roster = appState.roster.current
            roster.grantGold(battleEarnedGold)
            appState.roster.current = roster
        }
        appState.battle.isPaused = false
        appState.battle.activeBattle = nil
        appState.battle.preview = nil
    }

    private func updateMusicPreview(for stage: Stage?) {
        guard appState.battle.activeBattle == nil,
              let stage,
              let enemyID = stage.encounter.battleEnemyID
        else {
            appState.battle.preview = nil
            return
        }

        appState.battle.preview = BattleMusicPreview(stageID: stage.id, enemyID: enemyID)
    }

    private func completeStage(_ stage: Stage, hero: Combatant, pet: Combatant, battleEarnedGold: Int = 0) {
        var roster = appState.roster.current
        var inventory = appState.inventory.current
        var journey = appState.journey.current
        StageCompletion.complete(
            stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            in: chapters,
            roster: &roster,
            inventory: &inventory,
            journey: &journey
        )
        appState.roster.current = roster
        appState.inventory.current = inventory
        appState.journey.current = journey
        pendingScrollTarget = appState.journey.current.activeStageID ?? "chapter-2-locked"
    }

    private func chapter(containing stage: Stage) -> Chapter {
        chapters.first { $0.id == stage.chapterID } ?? currentChapter
    }

    private var activeHero: Combatant {
        appState.roster.heroes.first { $0.id == appState.roster.current.activeHeroID } ??
            appState.roster.heroes.first ??
            appState.roster.collectionHeroes[0]
    }

    private var activePet: Combatant {
        appState.roster.pets.first { $0.id == appState.roster.current.activePetID } ??
            appState.roster.pets.first ??
            appState.roster.collectionPets[0]
    }
}

private struct StageMapMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct JourneyMapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let chapter: Chapter
    let progress: JourneyProgressState
    @Binding var pendingScrollTarget: String?
    let onStageTap: (Stage) -> Void

    private var totalCount: Int {
        chapter.stages.count
    }

    private var completedCount: Int {
        chapter.stages.filter { progress.isCompleted($0) }.count
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    chapterHeader

                    StagePathView(
                        path: visiblePath,
                        theme: chapter.theme,
                        onStageTap: onStageTap
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .padding(.top, 12)
            }
            .scrollContentBackground(.hidden)
            .background {
                ChapterMapBackground(chapter: chapter)
            }
            .navigationTitle(chapter.title)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                centerActiveNode(with: proxy)
            }
            .onChange(of: progress.activeStageID) { _, _ in
                centerActiveNode(with: proxy)
            }
            .onChange(of: pendingScrollTarget) { _, target in
                guard let target else { return }
                withAnimation(scrollAnimation) {
                    proxy.scrollTo(target, anchor: .center)
                }
                pendingScrollTarget = nil
            }
        }
    }

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Chapter Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(completedCount)/\(totalCount) Cleared")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(completedCount), total: Double(totalCount))
                .tint(chapter.theme.tint)
                .progressViewStyle(.linear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var visiblePath: VisibleStagePath {
        VisibleStagePath(chapter: chapter, progress: progress)
    }

    private var scrollAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.45)
    }

    private func centerActiveNode(with proxy: ScrollViewProxy) {
        let target = progress.activeStageID ?? "chapter-2-locked"
        DispatchQueue.main.async {
            withAnimation(scrollAnimation) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}

private struct ChapterMapBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let chapter: Chapter

    var body: some View {
        ZStack {
            TrinketDesign.Colors.appBackground

            if !reduceTransparency,
               let bgImageName = ArtCatalog.backgroundArtByID[chapter.id]?.imageName {
                Image(bgImageName)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 8)
                    .opacity(backgroundImageOpacity)
                    .accessibilityHidden(true)
            }

            LinearGradient(
                colors: backgroundOverlayColors,
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var backgroundImageOpacity: Double {
        colorScheme == .dark ? 0.30 : 0.32
    }

    private var backgroundOverlayColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(.systemBackground).opacity(0.70),
                Color(.systemBackground).opacity(0.58),
                Color(.systemBackground).opacity(0.82)
            ]
        }

        return [
            Color(.systemBackground).opacity(0.56),
            Color(.systemBackground).opacity(0.48),
            Color(.systemBackground).opacity(0.74)
        ]
    }
}

private struct VisibleStagePath {
    let nodes: [VisibleStageNode]
    let showsChapterGate: Bool
    let showsTrailContinuation: Bool

    init(chapter: Chapter, progress: JourneyProgressState) {
        let stages = chapter.stages
        guard !stages.isEmpty else {
            nodes = []
            showsChapterGate = false
            showsTrailContinuation = false
            return
        }

        let activeIndex = progress.activeStageID.flatMap { activeStageID in
            stages.firstIndex { $0.id == activeStageID }
        }
        let lastCompletedIndex = stages.lastIndex { progress.isCompleted($0) }
        let anchorIndex = activeIndex ?? lastCompletedIndex ?? 0
        let startIndex = max(stages.startIndex, anchorIndex - 2)
        let endIndex: Int
        if let activeIndex {
            endIndex = min(stages.index(before: stages.endIndex), activeIndex + 1)
        } else {
            endIndex = min(stages.index(before: stages.endIndex), anchorIndex)
        }

        nodes = (startIndex ... endIndex).map { index in
            let stage = stages[index]
            return VisibleStageNode(
                stage: stage,
                state: Self.state(for: stage, progress: progress)
            )
        }
        let finalStageID = stages.last?.id
        showsChapterGate = nodes.contains { node in
            node.stage.id == finalStageID
        }
        showsTrailContinuation = !showsChapterGate && endIndex < stages.index(before: stages.endIndex)
    }

    private static func state(for stage: Stage, progress: JourneyProgressState) -> StageNodeState {
        if progress.isActive(stage) { return .active }
        if progress.isCompleted(stage) {
            return progress.isLastCompleted(stage) ? .justCompleted : .completed
        }
        return .future
    }
}

private struct VisibleStageNode: Identifiable {
    let stage: Stage
    let state: StageNodeState

    var id: String {
        stage.id
    }
}

private enum StageNodeState: Equatable {
    case completed
    case justCompleted
    case active
    case future
}

private struct StagePathView: View {
    let path: VisibleStagePath
    let theme: ChapterTheme
    let onStageTap: (Stage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(path.nodes.enumerated()), id: \.element.id) { index, node in
                let isFirst = index == 0
                let isLast = index == path.nodes.count - 1 && !path.showsChapterGate && !path.showsTrailContinuation

                StageTimelineRow(
                    node: node,
                    theme: theme,
                    isFirst: isFirst,
                    isLast: isLast,
                    onTap: { onStageTap(node.stage) }
                )
                .id(node.stage.id)
            }

            if path.showsChapterGate {
                StageTimelineGateRow(
                    theme: theme,
                    isLast: true
                )
                .id("chapter-2-locked")
            } else if path.showsTrailContinuation {
                StageTrailContinuationRow(theme: theme)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

private struct StageTimelineRow: View {
    let node: VisibleStageNode
    let theme: ChapterTheme
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TimelineSegment(
                isVisible: !isFirst,
                isComplete: topColored,
                color: theme.tint,
                height: 24
            )

            stageNode

            TimelineSegment(
                isVisible: !isLast,
                isComplete: bottomColored,
                color: theme.tint,
                height: 28
            )
        }
    }

    @ViewBuilder
    private var stageNode: some View {
        Button(action: onTap) {
            StageNodeView(
                stage: node.stage,
                state: node.state,
                theme: theme
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Stage \(node.stage.chapterNumber)-\(node.stage.stageNumber) Node")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var topColored: Bool {
        node.state == .completed || node.state == .justCompleted || node.state == .active
    }

    private var bottomColored: Bool {
        node.state == .completed || node.state == .justCompleted
    }

    private var accessibilityLabel: String {
        let fullLabel = "Stage \(node.stage.chapterNumber)-\(node.stage.stageNumber)"
        switch node.state {
        case .active:
            return "\(fullLabel), active \(node.stage.encounter.title)"
        case .completed, .justCompleted:
            return "\(fullLabel), complete"
        case .future:
            return "\(fullLabel), locked"
        }
    }

    private var accessibilityHint: String {
        switch node.state {
        case .active:
            return "Opens the stage preview."
        case .completed, .justCompleted:
            return "Completed stages are not replayable yet."
        case .future:
            return "Locked stages are not available yet."
        }
    }
}

private struct TimelineSegment: View {
    let isVisible: Bool
    let isComplete: Bool
    let color: Color
    let height: CGFloat

    var body: some View {
        Rectangle()
            .fill(isVisible ? segmentColor : Color.clear)
            .frame(width: 2, height: height)
    }

    private var segmentColor: Color {
        isComplete ? color.opacity(0.65) : Color.secondary.opacity(0.22)
    }
}

private struct StageNodeView: View {
    let stage: Stage
    let state: StageNodeState
    let theme: ChapterTheme

    var body: some View {
        HStack(spacing: 12) {
            encounterBadge

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(stage.mapLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(labelStyle)

                    Text(stage.encounter.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(stage.title)
                    .font(.subheadline.weight(state == .active ? .semibold : .medium))
                    .foregroundStyle(titleStyle)
            }
            .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 268, alignment: .leading)
        .frame(minHeight: 72, alignment: .leading)
        .background(nodeBackground)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(nodeStroke, lineWidth: state == .active ? 1.5 : 1)
        }
        .shadow(color: shadowColor, radius: state == .active ? 8 : 3, y: state == .active ? 4 : 2)
    }

    private var labelStyle: Color {
        state == .active ? .primary : .secondary
    }

    private var titleStyle: Color {
        state == .future ? .secondary : .primary
    }

    private var nodeBackground: Color {
        switch state {
        case .active:
            return theme.tint.opacity(0.16)
        case .completed, .justCompleted, .future:
            return Color(.secondarySystemBackground).opacity(0.88)
        }
    }

    private var nodeStroke: Color {
        state == .active ? theme.tint.opacity(0.55) : Color.secondary.opacity(0.16)
    }

    private var shadowColor: Color {
        state == .active ? theme.tint.opacity(0.18) : .black.opacity(0.05)
    }

    private var symbolTint: Color {
        switch stage.encounter {
        case .battle:
            return state == .active ? theme.tint : .secondary
        case .event:
            return state == .active ? theme.secondaryTint : .secondary
        case .shop:
            return state == .active ? theme.tint : .secondary
        case .rest:
            return state == .active ? theme.secondaryTint : .secondary
        }
    }

    private var encounterBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(symbolTint.opacity(state == .active ? 0.16 : 0.10))
                .frame(width: 44, height: 44)

            Image(systemName: stage.encounter.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(symbolTint)
                .frame(width: 44, height: 44)

            if let statusSymbol {
                Image(systemName: statusSymbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(statusSymbolTint)
                    .padding(3)
                    .background(TrinketDesign.Colors.appBackground, in: Circle())
                    .offset(x: 4, y: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private var statusSymbol: String? {
        switch state {
        case .completed, .justCompleted:
            return "checkmark.circle.fill"
        case .future:
            return "lock.circle.fill"
        case .active:
            return nil
        }
    }

    private var statusSymbolTint: Color {
        switch state {
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success
        case .future, .active:
            return .secondary
        }
    }
}

private struct StageTimelineGateRow: View {
    let theme: ChapterTheme
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            TimelineSegment(
                isVisible: true,
                isComplete: false,
                color: theme.tint,
                height: 28
            )

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                        .frame(width: 44, height: 44)

                    Image(systemName: "lock.rectangle.on.rectangle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Chapter 2")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text("Next Chapter Locked")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 268, alignment: .leading)
            .frame(minHeight: 72, alignment: .leading)
            .background(Color(.secondarySystemBackground).opacity(0.72))
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            }

            TimelineSegment(
                isVisible: !isLast,
                isComplete: false,
                color: theme.tint,
                height: 28
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Chapter 2 Locked")
    }
}

private struct StageTrailContinuationRow: View {
    let theme: ChapterTheme

    var body: some View {
        VStack(spacing: 8) {
            TimelineSegment(
                isVisible: true,
                isComplete: false,
                color: theme.tint,
                height: 28
            )

            Image(systemName: "ellipsis")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 28)
                .accessibilityLabel("More stages ahead")
        }
    }
}

private extension Stage {
    var mapLabel: String {
        "\(chapterNumber)-\(stageNumber)"
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct StagePreviewSheet: View {
    @Environment(AppState.self) private var appState
    @State private var partyPicker: PartyPickerKind?

    let stage: Stage
    let chapter: Chapter
    let onPrimaryAction: () -> Void

    private let scrollCoordinateSpaceName = "StagePreviewScroll"

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let baseHeaderHeight = StagePreviewHeader.headerHeight(forWidth: geometry.size.width)

                ScrollView {
                    VStack(spacing: 0) {
                        StagePreviewHeader(
                            stage: stage,
                            subject: subject,
                            baseHeight: baseHeaderHeight,
                            coordinateSpaceName: scrollCoordinateSpaceName
                        )
                        .accessibilityIdentifier("Stage Preview Header")

                        VStack(alignment: .leading, spacing: 0) {
                            encounterInfoSection
                            partySection
                        }
                        .background(TrinketDesign.Colors.appBackground)
                    }
                    .padding(.bottom, 88)
                }
                .coordinateSpace(name: scrollCoordinateSpaceName)
                .background(TrinketDesign.Colors.appBackground)
                .ignoresSafeArea(edges: .top)
                .safeAreaInset(edge: .bottom) {
                    primaryActionBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
    }

    private var encounterInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Encounter")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(stage.flavorText)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var partySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Party")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                Button {
                    partyPicker = .hero
                } label: {
                    PartySelectionCard(
                        title: "Hero",
                        combatant: activeHero,
                        accessibilityIdentifier: "Selected Hero Card"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    partyPicker = .pet
                } label: {
                    PartySelectionCard(
                        title: "Pet",
                        combatant: activePet,
                        accessibilityIdentifier: "Selected Pet Card"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var primaryActionBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button(action: onPrimaryAction) {
                Text(stage.encounter.primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            // UIStyleCheck: allow - encounter sheets use the native prominent CTA.
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(chapter.theme.tint)
            .accessibilityIdentifier("\(stage.encounter.primaryActionTitle) Button")
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(TrinketDesign.Colors.appBackground)
    }

    private var subject: StagePreviewSubject {
        switch stage.encounter {
        case .battle:
            if let enemy = stageEnemy {
                return StagePreviewSubject(
                    type: "Enemy",
                    name: enemy.name,
                    symbolName: stage.encounter.symbolName,
                    tint: chapter.theme.tint,
                    combatant: enemy.combatant
                )
            }
            return StagePreviewSubject(
                type: "Enemy",
                name: "Unknown",
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.tint,
                combatant: nil
            )
        case .event:
            return StagePreviewSubject(
                type: "Mystery",
                name: stage.title,
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.secondaryTint,
                combatant: nil
            )
        case .shop:
            return StagePreviewSubject(
                type: "Shop",
                name: "Merchant",
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.tint,
                combatant: nil
            )
        case .rest:
            return StagePreviewSubject(
                type: "Rest",
                name: "Moonwell",
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.secondaryTint,
                combatant: nil
            )
        }
    }

    private var stageEnemy: Enemy? {
        guard let enemyID = stage.encounter.battleEnemyID else { return nil }
        return GameContent.enemy(matching: enemyID)
    }

    private var stageLabel: String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber)"
    }

    private var activeHero: Combatant {
        appState.roster.heroes.first { $0.id == appState.roster.current.activeHeroID } ??
            appState.roster.heroes.first ??
            appState.roster.collectionHeroes[0]
    }

    private var activePet: Combatant {
        appState.roster.pets.first { $0.id == appState.roster.current.activePetID } ??
            appState.roster.pets.first ??
            appState.roster.collectionPets[0]
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

private enum PartyPickerKind: String, Identifiable {
    case hero = "Hero"
    case pet = "Pet"

    var id: String {
        rawValue
    }

    var accessibilityIdentifier: String {
        "\(rawValue) Party Picker"
    }
}

private struct StagePreviewSubject {
    let type: String
    let name: String
    let symbolName: String
    let tint: Color
    let combatant: Combatant?
}

private struct StagePreviewHeader: View {
    let stage: Stage
    let subject: StagePreviewSubject
    let baseHeight: CGFloat
    let coordinateSpaceName: String

    static func headerHeight(forWidth width: CGFloat) -> CGFloat {
        min(max(width * 1.04, 340), 430)
    }

    var body: some View {
        GeometryReader { geometry in
            let pullDistance = max(geometry.frame(in: .named(coordinateSpaceName)).minY, 0)
            let scale = HeroHeaderLayout.overscrollScale(baseHeight: baseHeight, pullDistance: pullDistance)

            ZStack(alignment: .topLeading) {
                headerArt(width: geometry.size.width, height: baseHeight)
                    .scaleEffect(scale, anchor: .top)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                titleBlock
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: baseHeight + pullDistance)
            .clipped()
            .offset(y: -pullDistance)
        }
        .frame(height: baseHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stage \(stage.chapterNumber)-\(stage.stageNumber), \(subject.type), \(subject.name)")
    }

    @ViewBuilder
    private func headerArt(width: CGFloat, height: CGFloat) -> some View {
        if let combatant = subject.combatant {
            CombatantArtwork(combatant: combatant, variant: .hero)
                .frame(width: width, height: height)
                .clipped()
        } else {
            ZStack {
                subject.tint.opacity(0.18)

                Image(systemName: subject.symbolName)
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(subject.tint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
            .frame(width: width, height: height)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stage \(stage.chapterNumber)-\(stage.stageNumber)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))

            Text(subject.type.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))

            Text(subject.name)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct PartySelectionCard: View {
    let title: String
    let combatant: Combatant
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .clipShape(TrinketDesign.cardShape)
                }
                .trinketCardSurface()
                .frame(maxWidth: 132)

            Text(combatant.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 132)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct PartyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let kind: PartyPickerKind
    let combatants: [Combatant]
    let selectedID: String
    let onSelect: (Combatant) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(combatants) { combatant in
                        Button {
                            onSelect(combatant)
                            dismiss()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                CombatantCard(combatant: combatant)

                                if combatant.id == selectedID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(TrinketDesign.Colors.success)
                                        .padding(6)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(combatant.name) party option")
                    }
                }
                .padding(20)
            }
            .background(TrinketDesign.Colors.appBackground)
            .navigationTitle("Choose \(kind.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(kind.accessibilityIdentifier)
        }
    }
}
