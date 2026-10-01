import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

#if DEBUG
public struct BattleTransitionLabView: View {
    public init() {
        _fixture = State(initialValue: BattleTransitionLabFixture())
    }

    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    @State private var fixture: BattleTransitionLabFixture
    @State private var preset = BattleTransitionPreset.current
    @State private var screen = BattleTransitionScreen.preview
    @State private var isReady = false
    @State private var isControlsPresented = false
    @State private var pendingReplay: BattleTransitionReplay?
    @State private var replayTask: Task<Void, Never>?
    @State private var entrySettled = false
    @State private var handVisible = false
    @State private var veilOpacity = 0.0
    @State private var aperture = 1.0
    @State private var victoryVisible = false
    @State private var revealID = UUID()

    public var body: some View {
        ZStack {
            TrinketDesign.Colors.canvas.ignoresSafeArea()
            if isReady {
                BattleTransitionLabCanvas(
                    fixture: fixture,
                    screen: screen,
                    gathersPortraits: preset == .gather,
                    entrySettled: entrySettled,
                    handVisible: handVisible,
                )
                .trinketPresentationVisibility(screen != .victory)

                if screen == .victory {
                    VictoryView(
                        summary: fixture.summary,
                        primaryActionTitle: "Loot All",
                        primaryActionAccessibilityIdentifier: AccessibilityID.Battle.continueButton,
                        action: .collect(hapticsEnabled: false, claim: { true }, finish: reset),
                    )
                    .id(revealID)
                    .scaleEffect(preset == .gather && !victoryVisible ? 0.985 : 1)
                    .offset(y: preset == .gather && !victoryVisible ? 12 : 0)
                    .trinketPresentationVisibility(victoryVisible, opacity: victoryVisible ? 1 : 0)
                }
            } else {
                ProgressView()
            }

            (screen == .victory ? TrinketDesign.Colors.accent : TrinketDesign.Colors.arcane)
                .opacity(veilOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .mask {
            GeometryReader { geometry in
                Circle()
                    .frame(width: geometry.size.height * 2, height: geometry.size.height * 2)
                    .scaleEffect(aperture)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .overlay {
            if preset == .aperture {
                GeometryReader { geometry in
                    Circle()
                        .strokeBorder(
                            screen == .victory ? TrinketDesign.Colors.accentEmphasized : TrinketDesign.Colors.arcane,
                            lineWidth: 2,
                        )
                        .frame(width: geometry.size.height * 2, height: geometry.size.height * 2)
                        .scaleEffect(aperture)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .background(TrinketDesign.Colors.canvas.ignoresSafeArea())
        .environment(fixture.session)
        .environment(fixture.session.spectacle)
        .environment(fixture.session.feedback)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Controls", systemImage: "slider.horizontal.3") {
                    reset()
                    isControlsPresented = true
                }
                .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.controls)
                .disabled(!isReady)
            }
        }
        .sheet(isPresented: $isControlsPresented, onDismiss: beginPendingReplay) {
            controls
        }
        .preferredColorScheme(.dark)
        .task(id: displayScale) {
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
                    Text(preset.description)
                        .foregroundStyle(.secondary)
                }
                Section("Replay") {
                    replayButton("Replay Entry", replay: .entry, id: AccessibilityID.BattleTransitionLab.replayEntry)
                    replayButton("Replay Victory", replay: .victory, id: AccessibilityID.BattleTransitionLab.replayVictory)
                    replayButton("Play Both", replay: .both, id: AccessibilityID.BattleTransitionLab.playBoth)
                    Button("Reset", action: reset)
                        .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.reset)
                }
                Section {
                    Text("Isolated preview. Loot All only replays collection; no rewards or progress are saved.")
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

    private func reset() {
        replayTask?.cancel()
        replayTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            screen = .preview
            entrySettled = false
            handVisible = false
            veilOpacity = 0
            aperture = 1
            victoryVisible = false
            revealID = UUID()
        }
    }

    private func beginPendingReplay() {
        guard let replay = pendingReplay, isReady, scenePhase == .active else { return }
        pendingReplay = nil
        reset()
        replayTask = Task { @MainActor in
            do {
                if replay == .victory {
                    screen = .battle
                    entrySettled = true
                    handVisible = true
                }
                // Let the control sheet retire and the starting pose mount before playback.
                try await Task.sleep(for: .milliseconds(300))
                if replay != .victory {
                    try await transition(to: .battle)
                }
                if replay == .both {
                    try await Task.sleep(for: .seconds(1))
                }
                if replay != .entry {
                    try await transition(to: .victory)
                }
            } catch {
                // Reset and navigation own cancellation; an old replay never changes the new pose.
            }
        }
    }

    private func transition(to destination: BattleTransitionScreen) async throws {
        try Task.checkCancellation()
        let duration = destination == .battle ? 0.55 : 0.45
        switch preset {
        case .current:
            if destination == .battle {
                screen = .battle
                entrySettled = true
                handVisible = true
            } else {
                screen = .victory
                withAnimation(TrinketMotion.Screen.crossfade) { victoryVisible = true }
            }
        case .gather:
            if destination == .battle {
                withAnimation(.spring(duration: duration, bounce: 0)) { entrySettled = true }
                try await Task.sleep(for: .milliseconds(100))
                screen = .battle
                withAnimation(.spring(duration: 0.4, bounce: 0)) { handVisible = true }
                try await Task.sleep(for: .milliseconds(450))
            } else {
                withAnimation(.easeIn(duration: 0.16)) { handVisible = false; veilOpacity = 0.12 }
                try await Task.sleep(for: .milliseconds(160))
                screen = .victory
                withAnimation(.easeOut(duration: 0.29)) { victoryVisible = true; veilOpacity = 0 }
            }
        case .veil, .aperture:
            withAnimation(.easeInOut(duration: duration / 2)) {
                veilOpacity = preset == .veil ? 1 : 0.2
                if preset == .aperture {
                    aperture = 0
                }
            }
            try await Task.sleep(for: .seconds(duration / 2))
            screen = destination
            entrySettled = true
            handVisible = destination == .battle
            victoryVisible = destination == .victory
            withAnimation(.easeOut(duration: duration / 2)) { veilOpacity = 0; aperture = 1 }
        }
        try await Task.sleep(for: .seconds(duration / 2))
        try Task.checkCancellation()
    }
}

enum BattleTransitionPreset: String, CaseIterable, Identifiable {
    case current = "Current"
    case gather = "Gather & Release"
    case veil = "Soft Veil"
    case aperture = "Arcane Aperture"

    var id: Self {
        self
    }

    var description: String {
        switch self {
        case .current: "Immediate entry and the current victory crossfade."
        case .gather: "Portraits gather into position; the hand rises, then releases into warm rewards."
        case .veil: "An arcane veil bridges entry, with a golden veil into victory."
        case .aperture: "A small arcane opening expands into battle and warm victory."
        }
    }
}

enum BattleTransitionScreen { case preview, battle, victory }
private enum BattleTransitionReplay { case entry, victory, both }
#endif
