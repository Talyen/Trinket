import SwiftUI

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedStage: Stage?
    @State private var selectedCombatantDetail: CombatantCollectionDetailSelection?
    @State private var stageMessage: StageMapMessage?
    @State private var pendingScrollTarget: String?
    @State private var pauseBeforeSheet: Bool?

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
        .sheet(item: $selectedCombatantDetail, onDismiss: {
            guard appState.battle.activeBattle != nil else { return }
            appState.battle.isPaused = pauseBeforeSheet ?? false
            pauseBeforeSheet = nil
        }, content: { selection in
            CombatantCollectionDetailSheet(selection: selection)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        })
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
                    pauseBeforeSheet = appState.battle.isPaused
                    appState.battle.isPaused = true
                    selectedCombatantDetail = CombatantCollectionDetailSelection(battleSnapshot: detail)
                }
            )
            .id(activeBattle.id)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
        } else {
            ChapterStageSelectView(
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
        var ctx = StageCompletionContext(
            roster: appState.roster.current,
            inventory: appState.inventory.current,
            homestead: appState.homestead.current,
            journey: appState.journey.current
        )
        StageCompletion.complete(
            stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            in: chapters,
            context: &ctx
        )
        appState.roster.current = ctx.roster
        appState.inventory.current = ctx.inventory
        appState.homestead.current = ctx.homestead
        appState.journey.current = ctx.journey
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

private struct ChapterStageSelectView: View {
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
        GeometryReader { geometry in
            let headerHeight = Self.headerHeight(for: geometry.size.height)

            VStack(spacing: 0) {
                ChapterHeroHeader(
                    chapter: chapter,
                    completedCount: completedCount,
                    totalCount: totalCount,
                    height: headerHeight
                )

                StageDeckView(
                    deck: visibleDeck,
                    scrollAnimation: scrollAnimation,
                    pendingScrollTarget: $pendingScrollTarget,
                    onStageTap: onStageTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TrinketDesign.Colors.appBackground)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(TrinketDesign.Colors.appBackground)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var visibleDeck: VisibleStageDeck {
        VisibleStageDeck(chapter: chapter, progress: progress)
    }

    private var scrollAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.45)
    }

    private static func headerHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.54, 320), 450)
    }
}

private struct ChapterHeroHeader: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chapter: Chapter
    let completedCount: Int
    let totalCount: Int
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                TrinketDesign.Colors.appBackground

                if !reduceTransparency,
                   let bgImageName = ArtCatalog.backgroundArtByID[chapter.id]?.imageName {
                    Image(bgImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .accessibilityHidden(true)
                }

                LinearGradient(
                    colors: [
                        .black.opacity(0.03),
                        .black.opacity(0.08),
                        .black.opacity(0.56)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Chapter \(chapter.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(chapter.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Chapter Progress")
                            .font(.caption.weight(.semibold))

                        Spacer()

                        Text("\(completedCount)/\(totalCount) Cleared")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.86))

                    ProgressView(value: Double(completedCount), total: Double(totalCount))
                        .tint(chapter.theme.secondaryTint)
                        .progressViewStyle(.linear)
                }
                .frame(maxWidth: 360)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, metadataBottomPadding)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
    }

    private var metadataBottomPadding: CGFloat {
        min(max(height * 0.40, 144), 184)
    }
}

private struct VisibleStageDeck {
    let cards: [StageDeckCard]
    let scrollTargetID: String?

    init(chapter: Chapter, progress: JourneyProgressState) {
        let stages = chapter.stages
        guard !stages.isEmpty else {
            cards = []
            scrollTargetID = nil
            return
        }

        let activeIndex = progress.activeStageID.flatMap { activeStageID in
            stages.firstIndex { $0.id == activeStageID }
        }

        var visibleCards: [StageDeckCard] = []
        if let activeIndex {
            let previousIndex = activeIndex - 1
            if stages.indices.contains(previousIndex) {
                visibleCards.append(.stage(VisibleStageNode(
                    stage: stages[previousIndex],
                    state: Self.state(for: stages[previousIndex], progress: progress)
                )))
            }

            visibleCards.append(.stage(VisibleStageNode(
                stage: stages[activeIndex],
                state: .active
            )))

            let nextIndex = activeIndex + 1
            if stages.indices.contains(nextIndex) {
                visibleCards.append(.stage(VisibleStageNode(
                    stage: stages[nextIndex],
                    state: .future
                )))
            } else {
                visibleCards.append(.chapterGate)
            }

            scrollTargetID = stages[activeIndex].id
        } else {
            let lastCompletedIndex = stages.lastIndex { progress.isCompleted($0) } ?? stages.startIndex
            let previousIndex = max(stages.startIndex, lastCompletedIndex - 1)
            if previousIndex != lastCompletedIndex {
                visibleCards.append(.stage(VisibleStageNode(
                    stage: stages[previousIndex],
                    state: Self.state(for: stages[previousIndex], progress: progress)
                )))
            }

            visibleCards.append(.stage(VisibleStageNode(
                stage: stages[lastCompletedIndex],
                state: Self.state(for: stages[lastCompletedIndex], progress: progress)
            )))
            visibleCards.append(.chapterGate)
            scrollTargetID = "chapter-2-locked"
        }

        cards = visibleCards
    }

    private static func state(for stage: Stage, progress: JourneyProgressState) -> StageNodeState {
        if progress.isActive(stage) { return .active }
        if progress.isCompleted(stage) {
            return progress.isLastCompleted(stage) ? .justCompleted : .completed
        }
        return .future
    }
}

private enum StageDeckCard: Identifiable {
    case stage(VisibleStageNode)
    case chapterGate

    var id: String {
        switch self {
        case let .stage(node):
            return node.id
        case .chapterGate:
            return "chapter-2-locked"
        }
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

private struct StageDeckView: View {
    let deck: VisibleStageDeck
    let scrollAnimation: Animation?
    @Binding var pendingScrollTarget: String?
    let onStageTap: (Stage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 18) {
                Text("Current Path")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .center, spacing: 14) {
                        ForEach(deck.cards) { card in
                            StageDeckCardView(
                                card: card,
                                onStageTap: onStageTap
                            )
                            .containerRelativeFrame(.horizontal) { length, _ in
                                min(max(length - 56, 292), 340)
                            }
                            .id(card.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
            .padding(.top, 22)
            .padding(.bottom, 28)
            .onAppear {
                scrollToDeckTarget(with: proxy)
            }
            .onChange(of: deck.scrollTargetID) { _, _ in
                scrollToDeckTarget(with: proxy)
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

    private func scrollToDeckTarget(with proxy: ScrollViewProxy) {
        guard let target = deck.scrollTargetID else { return }
        DispatchQueue.main.async {
            withAnimation(scrollAnimation) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}

private struct StageDeckCardView: View {
    let card: StageDeckCard
    let onStageTap: (Stage) -> Void

    var body: some View {
        switch card {
        case let .stage(node):
            if node.state == .active {
                Button {
                    onStageTap(node.stage)
                } label: {
                    StageNodeView(stage: node.stage, state: node.state)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Stage \(node.stage.chapterNumber)-\(node.stage.stageNumber) Node")
                .accessibilityLabel(accessibilityLabel(for: node))
                .accessibilityHint("Opens the stage preview.")
            } else {
                StageNodeView(stage: node.stage, state: node.state)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Stage \(node.stage.chapterNumber)-\(node.stage.stageNumber) Node")
                    .accessibilityLabel(accessibilityLabel(for: node))
            }
        case .chapterGate:
            ChapterGateCardView()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("Chapter 2 Locked")
                .accessibilityLabel("Chapter 2, locked")
        }
    }

    private func accessibilityLabel(for node: VisibleStageNode) -> String {
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
}

private struct StageNodeView: View {
    let stage: Stage
    let state: StageNodeState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                encounterBadge

                VStack(alignment: .leading, spacing: 5) {
                    Text(stage.mapLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(labelStyle)

                    Text(statusTitle)
                        .font(.title3.weight(state == .active ? .bold : .semibold))
                        .foregroundStyle(titleStyle)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                if state == .future {
                    Text("The path ahead has not revealed itself.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label(statusLabel, systemImage: statusSymbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusTint)

                    Text(stage.flavorText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)

            if state == .active {
                HStack {
                    Label("Preview", systemImage: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(encounterStyle.color)
                        .labelStyle(.titleAndIcon)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 272, alignment: .topLeading)
        .background(tintLayer)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(nodeStroke, lineWidth: state == .active ? 1.5 : 1)
        }
        .shadow(color: shadowColor, radius: state == .active ? 14 : 4, y: state == .active ? 8 : 2)
    }

    private var labelStyle: Color {
        state == .active ? .primary : .secondary
    }

    private var titleStyle: Color {
        state == .future ? .secondary : .primary
    }

    private var tintLayer: Color {
        switch state {
        case .active:
            return Color(.secondarySystemBackground)
        case .completed, .justCompleted:
            return Color(.secondarySystemBackground).opacity(0.72)
        case .future:
            return Color(.tertiarySystemBackground).opacity(0.68)
        }
    }

    private var nodeStroke: Color {
        state == .active ? encounterStyle.color.opacity(0.68) : Color.secondary.opacity(0.18)
    }

    private var shadowColor: Color {
        state == .active ? encounterStyle.color.opacity(0.24) : .black.opacity(0.05)
    }

    private var encounterBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(badgeFill)
                .frame(width: 52, height: 52)

            Image(systemName: badgeSymbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(badgeTint)
                .frame(width: 52, height: 52)
        }
        .accessibilityHidden(true)
    }

    private var encounterStyle: StageEncounterMapStyle {
        stage.encounter.mapStyle
    }

    private var badgeFill: Color {
        switch state {
        case .active:
            return encounterStyle.color.opacity(0.20)
        case .completed, .justCompleted, .future:
            return Color.secondary.opacity(0.12)
        }
    }

    private var badgeTint: Color {
        switch state {
        case .active:
            return encounterStyle.color
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success
        case .future:
            return .secondary
        }
    }

    private var badgeSymbolName: String {
        switch state {
        case .completed, .justCompleted:
            return "checkmark.circle.fill"
        case .future:
            return "lock.fill"
        case .active:
            return stage.encounter.symbolName
        }
    }

    private var statusTitle: String {
        switch state {
        case .active, .completed, .justCompleted:
            return stage.title
        case .future:
            return "Unknown Path"
        }
    }

    private var statusLabel: String {
        switch state {
        case .active:
            return stage.encounter.title
        case .completed, .justCompleted:
            return "Cleared"
        case .future:
            return "Locked"
        }
    }

    private var statusSymbolName: String {
        switch state {
        case .active:
            return stage.encounter.symbolName
        case .completed, .justCompleted:
            return "checkmark.circle.fill"
        case .future:
            return "lock.fill"
        }
    }

    private var statusTint: Color {
        switch state {
        case .active:
            return encounterStyle.color
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success
        case .future:
            return .secondary
        }
    }
}

private struct StageEncounterMapStyle {
    let color: Color
}

private extension StageEncounter {
    var mapStyle: StageEncounterMapStyle {
        switch self {
        case .battle:
            return StageEncounterMapStyle(color: Color(red: 0.86, green: 0.18, blue: 0.16))
        case .event:
            return StageEncounterMapStyle(color: Color(red: 0.46, green: 0.36, blue: 0.86))
        case .shop:
            return StageEncounterMapStyle(color: Color(red: 0.88, green: 0.48, blue: 0.16))
        case .rest:
            return StageEncounterMapStyle(color: Color(red: 0.10, green: 0.64, blue: 0.58))
        }
    }
}

private struct ChapterGateCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: "lock.rectangle.on.rectangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Chapter 2")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("Next Chapter Locked")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("A new route will open after this chapter is complete.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 272, alignment: .topLeading)
        .background(Color(.tertiarySystemBackground).opacity(0.68))
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
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
