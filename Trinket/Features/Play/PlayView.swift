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
                        inventoryState: activeBattle.inventoryState
                    )
                },
                onVictoryContinue: {
                    completeActiveBattle(activeBattle)
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
            .navigationTitle("Play")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func handleStageTap(_ stage: Stage) {
        let progress = appState.journey.current
        if progress.isActive(stage) {
            selectedStage = stage
        } else if progress.isCompleted(stage) {
            stageMessage = StageMapMessage(
                title: "Stage Complete",
                message: "\(stage.displayTitle) is already complete. The path only moves forward."
            )
        } else {
            stageMessage = StageMapMessage(
                title: "Stage Locked",
                message: "Complete the active stage to unlock this point on the path."
            )
        }
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
        appState.battle.activeBattle = ActiveBattleConfiguration(
            stageID: stage.id,
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroProgression: appState.roster.current.progression(for: hero),
            petProgression: appState.roster.current.progression(for: pet),
            heroEquipmentLoadout: appState.roster.current.equipmentLoadout(for: hero),
            petEquipmentLoadout: appState.roster.current.equipmentLoadout(for: pet),
            inventoryState: appState.inventory.current
        )
    }

    private func completeActiveBattle(_ battle: ActiveBattleConfiguration) {
        if let stageID = battle.stageID,
           let stage = chapters.flatMap(\.stages).first(where: { $0.id == stageID }) {
            completeStage(stage, hero: battle.hero, pet: battle.pet)
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

    private func completeStage(_ stage: Stage, hero: Combatant, pet: Combatant) {
        var roster = appState.roster.current
        var inventory = appState.inventory.current
        var journey = appState.journey.current
        StageCompletion.complete(
            stage,
            hero: hero,
            pet: pet,
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
    let chapter: Chapter
    let progress: JourneyProgressState
    @Binding var pendingScrollTarget: String?
    let onStageTap: (Stage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    chapterHeader

                    StagePathView(
                        path: visiblePath,
                        theme: chapter.theme,
                        onStageTap: onStageTap
                    )
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(TrinketDesign.Colors.appBackground)
            .onAppear {
                centerActiveNode(with: proxy)
            }
            .onChange(of: progress.activeStageID) { _, _ in
                centerActiveNode(with: proxy)
            }
            .onChange(of: pendingScrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                pendingScrollTarget = nil
            }
        }
    }

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chapter \(chapter.number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(chapter.theme.tint)

            Text(chapter.title)
                .font(.largeTitle.bold())

            Text("Follow the forest path.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visiblePath: VisibleStagePath {
        VisibleStagePath(chapter: chapter, progress: progress)
    }

    private func centerActiveNode(with proxy: ScrollViewProxy) {
        let target = progress.activeStageID ?? "chapter-2-locked"
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.45)) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
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
                StagePathNode(
                    stage: node.stage,
                    state: node.state,
                    theme: theme,
                    onTap: { onStageTap(node.stage) }
                )
                .id(node.stage.id)

                if path.nodes[safe: index + 1] != nil {
                    StagePathConnector(color: connectorColor(after: node.state))
                } else if path.showsTrailContinuation {
                    StagePathContinuation()
                } else if path.showsChapterGate {
                    StagePathConnector(color: connectorColor(after: node.state))
                }
            }

            if path.showsChapterGate {
                LockedChapterGate()
                    .id("chapter-2-locked")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func connectorColor(after state: StageNodeState) -> Color {
        switch state {
        case .completed, .justCompleted:
            return theme.tint.opacity(0.46)
        case .active:
            return theme.tint.opacity(0.28)
        case .future:
            return Color.secondary.opacity(0.16)
        }
    }
}

private struct StagePathNode: View {
    let stage: Stage
    let state: StageNodeState
    let theme: ChapterTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: stage.encounter.symbolName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(iconStyle)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)

                Text(shortStageLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(textStyle)
                    .minimumScaleFactor(0.82)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(width: nodeWidth, height: nodeHeight)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(nodeFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(nodeStroke, lineWidth: state == .active ? 2 : 1)
            }
            .shadow(color: shadowColor, radius: shadowRadius, y: 2)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("Stage \(stage.chapterNumber)-\(stage.stageNumber) Node")
        .accessibilityLabel(accessibilityLabel)
    }

    private var shortStageLabel: String {
        "\(stage.chapterNumber)-\(stage.stageNumber)"
    }

    private var fullStageLabel: String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber)"
    }

    private var accessibilityLabel: String {
        switch state {
        case .active:
            return "\(fullStageLabel), active \(stage.encounter.title)"
        case .completed, .justCompleted:
            return "\(fullStageLabel), complete"
        case .future:
            return "\(fullStageLabel), locked"
        }
    }

    private var nodeWidth: CGFloat {
        switch state {
        case .active:
            return 118
        case .completed, .justCompleted, .future:
            return 102
        }
    }

    private var nodeHeight: CGFloat {
        state == .active ? 52 : 46
    }

    private var textStyle: Color {
        switch state {
        case .future:
            return .secondary
        case .completed, .justCompleted, .active:
            return .primary
        }
    }

    private var nodeFill: Color {
        switch state {
        case .active:
            return encounterTint.opacity(0.18)
        case .completed, .justCompleted:
            return Color.secondary.opacity(0.08)
        case .future:
            return Color.secondary.opacity(0.06)
        }
    }

    private var nodeStroke: Color {
        switch state {
        case .active:
            return encounterTint
        case .completed, .justCompleted:
            return theme.tint.opacity(0.38)
        case .future:
            return Color.secondary.opacity(0.18)
        }
    }

    private var shadowColor: Color {
        switch state {
        case .active:
            return theme.tint.opacity(0.24)
        case .completed, .justCompleted, .future:
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        state == .active ? 6 : 0
    }

    private var iconStyle: Color {
        switch state {
        case .active, .completed, .justCompleted:
            return encounterTint
        case .future:
            return .secondary
        }
    }

    private var encounterTint: Color {
        switch stage.encounter {
        case .battle:
            return .red
        case .event:
            return .indigo
        case .shop:
            return .orange
        case .rest:
            return .mint
        }
    }
}

private struct StagePathConnector: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let centerX = geometry.size.width / 2
                path.move(to: CGPoint(x: centerX, y: 0))
                path.addLine(to: CGPoint(x: centerX, y: geometry.size.height))
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 8])
            )
        }
        .frame(height: 42)
        .accessibilityHidden(true)
    }
}

private struct StagePathContinuation: View {
    var body: some View {
        VStack(spacing: 0) {
            StagePathConnector(color: Color.secondary.opacity(0.14))

            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.12 - Double(index) * 0.03))
                    .frame(width: 5, height: 5)
                    .padding(.vertical, 4)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LockedChapterGate: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                    }

                Image(systemName: "lock.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(width: 74, height: 54)

            Text("Chapter 2")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Chapter 2 Locked")
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
