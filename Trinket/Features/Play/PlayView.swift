import SwiftUI

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedStage: Stage?
    @State private var selectedCombatantDetail: CombatantCollectionDetailSelection?
    @State private var stageMessage: StageMapMessage?
    @State private var pendingScrollTarget: String?

    private var chapters: [Chapter] { GameContent.chapters }
    private var currentChapter: Chapter { chapters.first ?? GameContent.chapters[0] }

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
            .presentationDragIndicator(.visible)
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
        case .battle(let enemyID):
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
    }

    private func completeStage(_ stage: Stage, hero: Combatant, pet: Combatant) {
        StageCompletion.complete(
            stage,
            hero: hero,
            pet: pet,
            in: chapters,
            roster: &appState.roster.current,
            inventory: &appState.inventory.current,
            journey: &appState.journey.current
        )
        pendingScrollTarget = appState.journey.current.activeStageID ?? "chapter-2-locked"
    }

    private func chapter(containing stage: Stage) -> Chapter {
        chapters.first { $0.id == stage.chapterID } ?? currentChapter
    }

    private var activeHero: Combatant {
        appState.roster.heroes.first { $0.id == appState.roster.current.activeHeroID } ??
            appState.roster.heroes[0]
    }

    private var activePet: Combatant {
        appState.roster.pets.first { $0.id == appState.roster.current.activePetID } ??
            appState.roster.pets[0]
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

                    VStack(spacing: 0) {
                        LockedChapterPreview()
                            .id("chapter-2-locked")
                            .padding(.bottom, 18)

                        ForEach(Array(chapter.stages.reversed().enumerated()), id: \.element.id) { index, stage in
                            StageNodeRow(
                                stage: stage,
                                state: state(for: stage),
                                theme: chapter.theme,
                                isLast: index == chapter.stages.count - 1,
                                onTap: { onStageTap(stage) }
                            )
                            .id(stage.id)
                        }
                    }
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

            Text("Follow the forest path. Only the active stage can be entered.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Begin at the bottom and climb toward the heartwood.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func state(for stage: Stage) -> StageNodeState {
        if progress.isActive(stage) { return .active }
        if progress.isCompleted(stage) {
            return progress.isLastCompleted(stage) ? .justCompleted : .completed
        }
        return .future
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

private enum StageNodeState: Equatable {
    case completed
    case justCompleted
    case active
    case future
}

private struct StageNodeRow: View {
    let stage: Stage
    let state: StageNodeState
    let theme: ChapterTheme
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: nodeSymbolName)
                        .font(.headline)
                        .foregroundStyle(nodeSymbolStyle)
                        // UIStyleCheck: allow - stage node symbols need a stable slot.
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    Text(stageLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(primaryTextStyle)

                    if state == .justCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(theme.tint)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(backgroundStyle)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Stage \(stage.chapterNumber)-\(stage.stageNumber) Node")
            .accessibilityLabel(accessibilityLabel)

            if !isLast {
                Rectangle()
                    .fill(connectorStyle)
                    .frame(width: 3, height: 24)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var nodeSymbolName: String {
        switch state {
        case .completed, .justCompleted:
            return "checkmark"
        case .active:
            return stage.encounter.symbolName
        case .future:
            return "lock.fill"
        }
    }

    private var stageLabel: String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber)"
    }

    private var accessibilityLabel: String {
        switch state {
        case .active:
            return "\(stageLabel), active \(stage.encounter.title)"
        case .completed, .justCompleted:
            return "\(stageLabel), complete"
        case .future:
            return "\(stageLabel), locked"
        }
    }

    private var primaryTextStyle: Color {
        switch state {
        case .future:
            return .secondary
        case .completed, .justCompleted, .active:
            return .primary
        }
    }

    private var nodeSymbolStyle: Color {
        switch state {
        case .active:
            return theme.tint
        case .completed, .justCompleted:
            return theme.tint
        case .future:
            return .secondary
        }
    }

    private var connectorStyle: Color {
        switch state {
        case .completed, .justCompleted:
            return theme.tint.opacity(0.45)
        case .active:
            return theme.tint.opacity(0.25)
        case .future:
            return Color.secondary.opacity(0.18)
        }
    }

    private var backgroundStyle: Color {
        switch state {
        case .active:
            return theme.tint.opacity(0.16)
        case .completed, .justCompleted:
            return Color.secondary.opacity(0.08)
        case .future:
            return Color.secondary.opacity(0.05)
        }
    }
}

private struct LockedChapterPreview: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text("Chapter 2")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Chapter 2 Locked")
    }
}

private struct StagePreviewSheet: View {
    @Environment(AppState.self) private var appState
    @State private var partyPicker: PartyPickerKind?

    let stage: Stage
    let chapter: Chapter
    let onPrimaryAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    StagePreviewHeader(stage: stage, subject: subject)
                        .accessibilityIdentifier("Stage Preview Header")

                    encounterInfoSection
                    partySection

                    Button(action: onPrimaryAction) {
                        Text(stage.encounter.primaryActionTitle)
                            .frame(maxWidth: .infinity)
                    }
                    // UIStyleCheck: allow - encounter sheets use the native prominent CTA.
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(chapter.theme.tint)
                    .accessibilityIdentifier("\(stage.encounter.primaryActionTitle) Button")
                    .padding(20)
                }
            }
            .background(TrinketDesign.Colors.appBackground)
            .ignoresSafeArea(edges: .top)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Encounter")
                .font(.headline)

            LabeledContent("Stage") {
                Text(stageLabel)
            }

            LabeledContent("Type") {
                Text(subject.type)
            }

            LabeledContent("Name") {
                Text(subject.name)
            }

            Text(stage.flavorText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .font(.body)
        .padding(20)
    }

    private var partySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Party")
                .font(.headline)

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
        .padding(.top, 8)
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
            appState.roster.heroes[0]
    }

    private var activePet: Combatant {
        appState.roster.pets.first { $0.id == appState.roster.current.activePetID } ??
            appState.roster.pets[0]
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

    var id: String { rawValue }

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

    var body: some View {
        GeometryReader { geometry in
            let height = HeroHeaderLayout.headerHeight(forWidth: geometry.size.width)

            ZStack(alignment: .bottomLeading) {
                headerArt
                    .frame(width: geometry.size.width, height: height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

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
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stage \(stage.chapterNumber)-\(stage.stageNumber), \(subject.type), \(subject.name)")
    }

    @ViewBuilder
    private var headerArt: some View {
        if let combatant = subject.combatant {
            CombatantArtwork(combatant: combatant, variant: .hero)
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                subject.tint.opacity(0.18)

                Image(systemName: subject.symbolName)
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(subject.tint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
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

            CombatantCard(combatant: combatant)
        }
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
