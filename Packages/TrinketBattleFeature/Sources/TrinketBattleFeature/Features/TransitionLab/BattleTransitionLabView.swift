import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
public struct BattleTransitionLabView<StagePicker: View>: View {
    public init(
        stage: Stage,
        @ViewBuilder stagePicker: @escaping (@escaping () -> Bool) -> StagePicker,
    ) {
        _fixture = State(initialValue: BattleTransitionLabFixture(stage: stage))
        self.stagePicker = stagePicker
    }

    private let stagePicker: (@escaping () -> Bool) -> StagePicker
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    @State private var fixture: BattleTransitionLabFixture
    @State private var preset = BattleTransitionPreset.crossfade
    @State private var screen = BattleTransitionScreen.picker
    @State private var destination: BattleTransitionScreen?
    @State private var progress = 0.0
    @State private var isReady = false
    @State private var isControlsPresented = false
    @State private var pendingReplay: BattleTransitionReplay?
    @State private var replayTask: Task<Void, Never>?
    @State private var playbackID = UUID()
    @State private var revealID = UUID()

    public var body: some View {
        ZStack {
            TrinketDesign.Colors.canvas.ignoresSafeArea()
            if isReady {
                stagePicker(enterBattle)
                    .modifier(layer(.picker))
                BattleTransitionLabCanvas(fixture: fixture)
                    .modifier(layer(.battle))
                victory
                    .modifier(layer(.victory))

                if destination != nil, effectivePreset == .curtain {
                    GeometryReader { geometry in
                        transitionTint
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: geometry.size.width * (progress * 2 - 1) * (destination == .battle ? 1 : -1))
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            } else {
                ProgressView()
            }
        }
        .clipped()
        .environment(fixture.session)
        .environment(fixture.session.spectacle)
        .environment(fixture.session.feedback)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if screen == .battle {
                    Menu("Battle Preview") {
                        Button("Return to Stages", action: returnToStages)
                            .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.returnToStages)
                        Button("Show Victory") { start(.showVictory) }
                            .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.showVictory)
                    }
                    .disabled(replayTask != nil)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Controls", systemImage: "slider.horizontal.3") {
                    cancelPlayback(restoring: screen)
                    isControlsPresented = true
                }
                .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.controls)
                .disabled(!isReady)
            }
        }
        .sheet(isPresented: $isControlsPresented, onDismiss: beginPendingReplay) { controls }
        .preferredColorScheme(.dark)
        .task(id: displayScale) {
            isReady = false
            cancelPlayback(restoring: .picker)
            await fixture.session.prepareBattlePresentationAssets(displayScale: displayScale)
            guard !Task.isCancelled else { return }
            isReady = true
        }
        .onChange(of: preset) { _, _ in reset() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                pendingReplay = nil
                reset()
            }
        }
        .onDisappear {
            pendingReplay = nil
            reset()
            fixture.session.endBattle()
        }
    }

    private var victory: some View {
        let generation = playbackID
        let reveal = revealID
        return VictoryView(
            summary: fixture.summary,
            primaryActionTitle: "Loot All",
            primaryActionAccessibilityIdentifier: AccessibilityID.BattleTransitionLab.lootAll,
            action: .collect(hapticsEnabled: false, claim: { true }, finish: {
                guard playbackID == generation, revealID == reveal else { return }
                returnToStages()
            }),
        )
        .id(reveal)
    }

    private var effectivePreset: BattleTransitionPreset {
        destination == .victory ? .crossfade : preset
    }

    private var transitionTint: Color {
        screen == .victory ? TrinketDesign.Colors.accent : TrinketDesign.Colors.arcane
    }

    private func layer(_ representedScreen: BattleTransitionScreen) -> BattleTransitionLabLayer {
        BattleTransitionLabLayer(
            screen: representedScreen, source: screen, destination: destination,
            preset: effectivePreset, progress: progress,
            isInteractive: replayTask == nil && !isControlsPresented, tint: transitionTint,
        )
    }

    private var controls: some View {
        NavigationStack {
            Form {
                Section("Transition") {
                    Picker("Preset", selection: $preset) {
                        ForEach(BattleTransitionPreset.allCases) { variant in
                            Text(variant.rawValue).tag(variant)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.preset)
                    Text(preset.description).foregroundStyle(.secondary)
                }
                Section("Replay") {
                    replayButton("Replay Entry", replay: .entry, id: AccessibilityID.BattleTransitionLab.replayEntry)
                    replayButton("Replay Direct Exit", replay: .directExit, id: AccessibilityID.BattleTransitionLab.replayDirectExit)
                    replayButton(
                        "Replay Victory Return",
                        replay: .victoryReturn,
                        id: AccessibilityID.BattleTransitionLab.replayVictoryReturn,
                    )
                    replayButton("Play Full Journey", replay: .journey, id: AccessibilityID.BattleTransitionLab.playFullJourney)
                    Button("Reset", action: reset)
                        .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.reset)
                }
                Section {
                    Text(
                        "Fixed sample stages and rewards. Battle, Return to Stages, and Loot All only change this preview; no progress is saved.",
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Battle Transitions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isControlsPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private func replayButton(_ title: String, replay: BattleTransitionReplay, id: String) -> some View {
        Button(title) {
            pendingReplay = replay
            isControlsPresented = false
        }
        .accessibilityIdentifier(id)
        .disabled(!isReady)
    }

    private func enterBattle() -> Bool {
        guard screen == .picker, isReady, replayTask == nil else { return false }
        start(.entry)
        return true
    }

    private func returnToStages() {
        guard screen != .picker, replayTask == nil else { return }
        start(.returnToStages)
    }

    private func reset() {
        cancelPlayback(restoring: .picker)
        revealID = UUID()
    }

    private func cancelPlayback(restoring settledScreen: BattleTransitionScreen) {
        replayTask?.cancel()
        replayTask = nil
        playbackID = UUID()
        if settledScreen == .victory {
            revealID = UUID()
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            screen = settledScreen
            destination = nil
            progress = 0
        }
    }

    private func beginPendingReplay() {
        guard let replay = pendingReplay, isReady, scenePhase == .active else { return }
        pendingReplay = nil
        start(replay, afterSheet: true)
    }

    private func start(_ replay: BattleTransitionReplay, afterSheet: Bool = false) {
        guard isReady, replayTask == nil, scenePhase == .active else { return }
        if replay == .entry || replay == .journey {
            reset()
        } else if replay == .directExit || replay == .victoryReturn {
            cancelPlayback(restoring: .battle)
            revealID = UUID()
        }
        let id = playbackID
        replayTask = Task { @MainActor in
            do {
                // The sheet must retire and the settled source must mount before playback.
                try await Task.sleep(for: .milliseconds(afterSheet ? 300 : 16))
                switch replay {
                case .entry:
                    try await transition(to: .battle)
                case .directExit, .returnToStages:
                    try await transition(to: .picker)
                case .showVictory:
                    try await transition(to: .victory)
                case .victoryReturn:
                    try await transition(to: .victory)
                    try await Task.sleep(for: .seconds(1))
                    try await transition(to: .picker)
                case .journey:
                    try await transition(to: .battle)
                    try await Task.sleep(for: .seconds(1))
                    try await transition(to: .victory)
                    try await Task.sleep(for: .seconds(1))
                    try await transition(to: .picker)
                }
                try Task.checkCancellation()
                guard playbackID == id else { return }
                replayTask = nil
            } catch {
                guard playbackID == id else { return }
                reset()
            }
        }
    }

    private func transition(to target: BattleTransitionScreen) async throws {
        try Task.checkCancellation()
        if target == .victory {
            // The retained reward view starts its reveal while hidden; restart it at entry.
            revealID = UUID()
        }
        destination = target
        progress = 0
        let duration = target == .victory ? TrinketMotion.Screen.crossfadeDuration : preset.duration(entering: target == .battle)
        if effectivePreset == .curtain {
            withAnimation(.easeIn(duration: duration / 2)) { progress = 0.5 }
            try await Task.sleep(for: .seconds(duration / 2))
            try Task.checkCancellation()
            withAnimation(.easeOut(duration: duration / 2)) { progress = 1 }
            try await Task.sleep(for: .seconds(duration / 2))
        } else {
            let animation: Animation = target == .victory ? TrinketMotion.Screen.crossfade : .easeInOut(duration: duration)
            withAnimation(animation) { progress = 1 }
            try await Task.sleep(for: .seconds(duration))
        }
        try Task.checkCancellation()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            screen = target
            destination = nil
            progress = 0
        }
    }
}

private enum BattleTransitionReplay { case entry, directExit, victoryReturn, journey, showVictory, returnToStages }
#endif
