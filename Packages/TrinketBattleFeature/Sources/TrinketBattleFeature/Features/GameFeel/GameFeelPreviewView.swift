import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

#if DEBUG
/// Isolated presentation fixtures; replay never invokes production commands or save actions.
public struct GameFeelPreviewView: View {
    private enum Surface: String, CaseIterable {
        case combat = "Combat", loot = "Loot", purchase = "Purchase"
    }

    private let playSound: (String) -> Void
    @State private var fixture: BattleTransitionLabFixture
    @State private var surface = Surface.combat
    @State private var baseline = false
    @State private var holdsSample = false
    @State private var muted = false
    @State private var soundFamily = Keyword.physical
    @State private var replayID = UUID()
    @State private var purchaseToken = 0
    @State private var replayTask: Task<Void, Never>?
    @State private var bridgeID = UUID()
    @State private var eventID = 0
    @State private var artworkLease: PreparedArtworkLease?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    public init(stage: Stage, playSound: @escaping (String) -> Void) {
        _fixture = State(initialValue: BattleTransitionLabFixture(stage: stage))
        self.playSound = playSound
    }

    public var body: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            Picker("Preview", selection: $surface) {
                ForEach(Surface.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .accessibilityIdentifier(AccessibilityID.GameFeel.surface)

            if artworkLease == nil {
                ProgressView().frame(maxHeight: .infinity)
            } else {
                switch surface {
                case .combat: combat
                case .loot: loot.id(replayID)
                case .purchase: purchase
                }
            }
        }
        .environment(fixture.session)
        .environment(fixture.session.spectacle)
        .trinketScreenBackground()
        .navigationTitle("Game Feel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Mute Preview", isOn: $muted)
                    .accessibilityIdentifier(AccessibilityID.GameFeel.mute)
            }
        }
        .task(id: displayScale) {
            await fixture.session.prepareBattlePresentationAssets(displayScale: displayScale)
            let lease = await PreparedArtworkLease(names: sampleItems.flatMap {
                [$0.artReference?.imageName, $0.artReference?.thumbnailImageName].compactMap(\.self)
            })
            guard !Task.isCancelled else { return }
            artworkLease = lease
            fixture.session.feedback.installBridge(ownerID: bridgeID) { [weak feedback = fixture.session.feedback] update in
                CombatFeedbackChipBridge.publish(update, onEvict: { [weak feedback] ids in
                    feedback?.evictedItemIDs.formUnion(ids)
                })
            }
        }
        .onChange(of: surface) { _, _ in reset() }
        .onChange(of: baseline) { _, _ in reset() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                reset()
            }
        }
        .onDisappear {
            reset()
            fixture.session.feedback.uninstallBridge(ownerID: bridgeID)
            fixture.session.endBattle()
            artworkLease = nil
        }
    }

    private var combat: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            BattleTransitionLabCanvas(fixture: fixture)
                .overlay {
                    GeometryReader { geometry in
                        let hand = BattleHandLayout.frame(in: geometry.size)
                        ForEach(fixture.session.cardPlayback.casts) { cast in
                            AutomaticCardCastView(
                                cast: cast,
                                stagingFrame: CGRect(x: hand.minX, y: 0, width: hand.width, height: max(0, hand.minY)),
                                handWidth: hand.width,
                            ) { fixture.session.cardPlayback.remove(id: cast.id) }
                        }
                    }
                    .allowsHitTesting(false)
                }
            if holdsSample {
                Button("Reset Sample") { reset() }
                    .trinketSecondaryActionButton(controlSize: .small)
                    .accessibilityIdentifier(AccessibilityID.GameFeel.resetSample)
            } else {
                combatControls
            }
        }
    }

    private var combatControls: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            Toggle("Baseline Attack Timing", isOn: $baseline)
                .padding(.horizontal)
                .accessibilityIdentifier(AccessibilityID.GameFeel.baseline)
            HStack {
                Button("Tap Attack") { attack(prepared: false) }
                    .accessibilityIdentifier(AccessibilityID.GameFeel.tap)
                Button("Drag Release") { attack(prepared: true) }
                    .accessibilityIdentifier(AccessibilityID.GameFeel.drag)
                Menu("Busy Combat") {
                    ForEach(GameFeelCombatScenario.allCases) { scenario in
                        Button(scenario.rawValue) { play(scenario) }
                    }
                }
                .accessibilityIdentifier(AccessibilityID.GameFeel.busy)
            }
            .trinketSecondaryActionButton(controlSize: .small)
            HStack {
                Picker("Damage Type", selection: $soundFamily) {
                    ForEach([Keyword.physical, .burn, .freeze, .stun, .poison, .holy], id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
                Button("Ordinary") { hitSound(critical: false) }
                Button("Critical") { hitSound(critical: true) }
            }
            .trinketSecondaryActionButton(controlSize: .small)
            .padding(.horizontal)
        }
    }

    private var loot: some View {
        VStack {
            RewardRevealExperienceScreen(
                eyebrow: nil, title: "Preview Loot",
                titleAccessibilityIdentifier: AccessibilityID.GameFeel.loot,
                loot: .init(
                    items: sampleItems, gold: 75, materials: [], showsIncreasePrefix: true,
                    emptyMessage: nil, itemAccessibilityID: { "Game Feel Reward \($0)" },
                ),
                primaryActionTitle: "Replay Loot", primaryActionAccessibilityIdentifier: AccessibilityID.GameFeel.replayLoot,
                action: .immediate { replayID = UUID(); return true },
                allowsImmediatePrimaryAction: true,
                onExceptionalReveal: { sound(SFXID.lootExceptional) },
            )
        }
    }

    private var purchase: some View {
        VStack(spacing: TrinketDesign.Spacing.large) {
            if let item = sampleItems.first {
                EncounterItemTile(item: item, showsName: true, onSelect: {})
                    .frame(width: 180)
                    .trinketPurchaseMotion(trigger: purchaseToken, isActive: scenePhase == .active)
            }
            Button("Replay Purchase") {
                purchaseToken &+= 1
                sound(SFXID.uiBuySell)
            }
            .trinketPrimaryActionButton()
            .accessibilityIdentifier(AccessibilityID.GameFeel.purchase)
            Spacer()
        }
        .padding()
    }

    private var sampleItems: [InventoryItem] {
        [GameContent.sampleInventoryItems.first { $0.rarity == .astral }, GameContent.uniqueItems.first].compactMap(\.self)
    }

    private func sound(_ id: String) {
        guard !muted, scenePhase == .active else { return }
        playSound(id)
    }

    private func hitSound(critical: Bool) {
        let event = ActionEvent(
            id: 1, kind: .abilityDamage, actorID: "hero", actorName: "Hero", abilityName: "Preview",
            targetID: "enemy", targetName: "Enemy", amount: 12, keyword: soundFamily, isCritical: critical,
        )
        if let id = CombatSFXMapper.clipID(for: [event]) {
            sound(id)
        }
    }

    private func reset() {
        replayTask?.cancel()
        replayTask = nil
        holdsSample = false
        fixture.session.feedback.clear()
        fixture.session.cardPlayback.reset()
        fixture.session.installSimulationPresentation()
        replayID = UUID()
    }

    private func attack(prepared: Bool) {
        replayTask?.cancel()
        let feedback = fixture.session.feedback
        let heroID = fixture.session.heroID ?? "hero"
        // The simulation stays suspended; only its presentation clock is exercised.
        feedback.setSuspended(false)
        let preparation = prepared ? 0 : (baseline ? 0.10 : CombatFeedbackAttackRecipes.manualPreparation)
        let swing = baseline ? 0.15 : CombatFeedbackAttackRecipes.manualSwing
        let recovery = baseline ? 0.45 : CombatFeedbackAttackRecipes.manualRecovery
        feedback.publishAttack(
            prepared ? .swing : .windUp,
            for: heroID,
            at: .now,
            duration: prepared ? swing : preparation,
        )
        record(.rapid, index: 0)
        replayTask = Task { @MainActor in
            if preparation > 0 {
                try? await Task.sleep(for: .seconds(preparation))
                guard !Task.isCancelled else { return }
                feedback.publishAttack(.swing, for: heroID, at: .now, duration: swing)
            }
            try? await Task.sleep(for: .seconds(swing))
            guard !Task.isCancelled else { return }
            feedback.publishAttack(.recover, for: heroID, at: .now, duration: recovery)
        }
    }

    private func play(_ scenario: GameFeelCombatScenario) {
        reset()
        holdsSample = true
        fixture.session.feedback.setSuspended(false)
        replayTask = Task { @MainActor in
            for index in 0 ..< 6 {
                guard !Task.isCancelled else { return }
                if scenario == .automatic, let card = fixture.session.presentation.hand.first {
                    let date = Date.now
                    fixture.session.cardPlayback.append(
                        card, at: date, activationAt: date.addingTimeInterval(BattleMotion.automaticCardRevealDuration),
                    )
                    record(.rapid, index: index)
                    try? await Task.sleep(for: .seconds(BattleMotion.automaticCardRevealDuration))
                }
                guard !Task.isCancelled else { return }
                record(scenario, index: index)
                try? await Task.sleep(for: .milliseconds(80))
            }
            guard !Task.isCancelled else { return }
            // Freeze the real chip clock so delayed device captures can inspect overlap.
            fixture.session.feedback.setSuspended(true)
        }
    }

    private func record(_ scenario: GameFeelCombatScenario, index: Int) {
        guard let hero = fixture.session.presentation.hero?.combatant,
              let enemy = fixture.session.presentation.enemy?.combatant else { return }
        let events = GameFeelCombatEvents.make(scenario, index: index, nextID: &eventID, hero: hero, enemy: enemy)
        let dependencies = BattlePresentationDependencies(
            playSFX: { ids in ids.forEach(sound) }, warmSFX: { _, _ in }, hapticsEnabled: { false },
        )
        fixture.session.feedback.record(events, environment: dependencies)
        if scenario == .lethal, index == 5, let state = fixture.session.engineState {
            let snapshot = state.battlePresentationSnapshot(configurationID: fixture.configuration.id)
            fixture.session.presentation.install(BattlePresentationSnapshot(preview: snapshot, enemyHealth: 0))
        }
    }
}
#endif
