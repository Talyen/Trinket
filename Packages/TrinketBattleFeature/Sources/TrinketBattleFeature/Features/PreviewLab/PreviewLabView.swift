import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport

#if DEBUG

public struct PreviewLabView: View {
    public init() {
        let enemyID = Self.defaultEnemyID
        let heroID = Self.defaultHeroID
        let companionID = Self.defaultCompanionID
        let configuration = PreviewLab.makeConfiguration(
            enemyID: enemyID,
            heroID: heroID,
            companionID: companionID,
        )
        let session = BattleSession(
            openingHandDrawStagger: 0,
            presentationEnvironment: PreviewLab.dependencies,
        )
        _ = session.activate(configuration)
        _labSession = State(initialValue: session)
        _configuration = State(initialValue: configuration)
        _selectedEnemyID = State(initialValue: enemyID)
        _selectedHeroID = State(initialValue: heroID)
        _selectedCompanionID = State(initialValue: companionID)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var labSession: BattleSession
    @State private var configuration: BattleRunConfiguration
    @State private var selectedEnemyID: String
    @State private var selectedHeroID: String
    @State private var selectedCompanionID: String
    @State private var isControlsPresented = false

    public var body: some View {
        BattleView(
            configuration: configuration,
            presentationContext: .empty,
            battleSession: labSession,
            completeVictory: { _ in false },
            restartBattle: restart,
            retreat: { dismiss() },
        )
        .toolbar {
            if isCinematicClear {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isControlsPresented = true
                    } label: {
                        Label("Preview Lab Controls", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("Preview Lab Controls")
                }
            }
        }
        .sheet(isPresented: $isControlsPresented) {
            NavigationStack {
                Form {
                    subjectSection
                }
                .navigationTitle("Preview Lab")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isControlsPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: prepare)
        .onDisappear(perform: teardown)
    }

    private var subjectSection: some View {
        Section("Subject") {
            Picker("Hero", selection: $selectedHeroID) {
                ForEach(GameContent.heroes, id: \.id) { hero in
                    Text(hero.name).tag(hero.id)
                }
            }
            .onChange(of: selectedHeroID) { _, _ in
                restart()
            }

            Picker("Companion", selection: $selectedCompanionID) {
                ForEach(PreviewLab.companionOptions, id: \.id) { combatant in
                    Text(combatant.name).tag(combatant.id)
                }
            }
            .onChange(of: selectedCompanionID) { _, _ in
                restart()
            }

            Picker("Enemy", selection: $selectedEnemyID) {
                ForEach(GameContent.enemies, id: \.id) { enemy in
                    Text(enemy.name).tag(enemy.id)
                }
            }
            .onChange(of: selectedEnemyID) { _, _ in
                restart()
            }
        }
    }

    private var isCinematicClear: Bool {
        !labSession.spectacle.outcomePresentation.isOutcomePresented
    }

    private func prepare() {
        warmSelectedCinematics()
        Task { @MainActor in
            await warmArtwork()
        }
    }

    private func teardown() {
        isControlsPresented = false
        labSession.endBattle()
    }

    private func restart() {
        configuration = PreviewLab.makeConfiguration(
            enemyID: selectedEnemyID,
            heroID: selectedHeroID,
            companionID: selectedCompanionID,
        )
        _ = labSession.restart(configuration)
        warmSelectedCinematics()
        Task { @MainActor in
            await warmArtwork()
        }
    }

    private func warmSelectedCinematics() {
        guard labSession.areUltimateCinematicAnimationsEnabled else { return }
        if let ultimate = PreviewLab.cinematicUltimate(for: selectedHeroID) {
            BattleCinematicPlayer.shared.warm(actorID: selectedHeroID, abilityID: ultimate.id)
        }
        if let ultimate = PreviewLab.cinematicUltimate(for: selectedCompanionID) {
            BattleCinematicPlayer.shared.warm(actorID: selectedCompanionID, abilityID: ultimate.id)
        }
    }

    private func warmArtwork() async {
        let hero = GameContent.heroes.first { $0.id == selectedHeroID }
        let companion = PreviewLab.companionOptions.first { $0.id == selectedCompanionID }
        let enemy = GameContent.enemy(matching: selectedEnemyID)?.combatant
        let combatants = [hero, companion, enemy].compactMap(\.self)
        let names = combatants.flatMap { combatant -> [String] in
            guard let reference = combatant.artReference else { return [] }
            return [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
        }
        await PreparedArtworkCache.shared.prepare(names: names)
    }

    private static var defaultEnemyID: String {
        GameContent.enemies.first?.id ?? ""
    }

    private static var defaultHeroID: String {
        GameContent.heroes.first { $0.id == "rogue" }?.id ?? GameContent.heroes.first?.id ?? ""
    }

    private static var defaultCompanionID: String {
        PreviewLab.companionOptions.first { $0.id == "knight" }?.id
            ?? PreviewLab.companionOptions.first?.id ?? ""
    }
}

private enum PreviewLab {
    @MainActor
    static var dependencies: BattleRuntimeDependencies {
        BattleRuntimeDependencies(
            playSFX: { _ in },
            warmSFX: { _, _ in },
            hapticsEnabled: { false },
            effectsVolume: { 1 },
            shouldAutoSkipUltimateCinematic: { _, _ in false },
        )
    }

    static var companionOptions: [Combatant] {
        GameContent.heroes + GameContent.companions
    }

    static func cinematicUltimate(for combatantID: String) -> Ability? {
        switch combatantID {
        case "rogue": .shadowstep
        case "knight": .avatarOfJustice
        default: nil
        }
    }

    static func makeConfiguration(
        enemyID: String,
        heroID: String,
        companionID: String,
    ) -> BattleRunConfiguration {
        let hero = GameContent.heroes.first { $0.id == heroID } ?? GameContent.heroes.first
        let companion = companionOptions.first { $0.id == companionID } ?? GameContent.companions.first
        let enemy = GameContent.enemy(matching: enemyID) ?? GameContent.enemies.first
        return BattleRunConfiguration(
            runKey: nil,
            rngSeed: 1772,
            hero: BattleRunConfiguration.PartyMember(
                combatant: hero.map { labCombatant($0, ultimate: cinematicUltimate(for: heroID)) }
                    ?? Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: []),
                progression: .initial,
                equipmentLoadout: .init(),
                modifiers: .zero,
            ),
            companion: BattleRunConfiguration.PartyMember(
                combatant: companion.map { labCombatant($0, ultimate: cinematicUltimate(for: companionID)) }
                    ?? Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 20, abilities: []),
                progression: .initial,
                equipmentLoadout: .init(),
                modifiers: .zero,
            ),
            enemy: enemy.map { labCombatant($0.combatant) },
            enemyEncounterLevel: nil,
            enemyModifiers: .zero,
        )
    }

    static func labCombatant(_ combatant: Combatant, ultimate: Ability? = nil) -> Combatant {
        let choices = ultimate.map {
            combatant.abilityChoices.withSelectedLoadout(AbilityLoadout(ultimate: $0))
        } ?? combatant.abilityChoices
        return Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: 999,
            maxMana: combatant.maxMana,
            actionIntervalTurns: combatant.actionIntervalTurns,
            abilityChoices: choices,
        )
    }
}

#endif
