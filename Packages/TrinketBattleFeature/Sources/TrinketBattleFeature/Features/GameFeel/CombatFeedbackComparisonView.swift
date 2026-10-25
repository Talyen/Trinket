import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
/// Replays fixed committed-result fixtures through the real feedback lane and battlefield.
public struct CombatFeedbackComparisonView: View {
    private enum Mode: String, CaseIterable { case baseline = "Baseline", balanced = "Balanced" }
    private enum Sample: String,
        CaseIterable { case single = "Single", rapid = "Rapid", mixed = "Mixed", corners = "Corners", reactions = "Reactions" }
    @State private var fixture: BattleTransitionLabFixture
    @State private var mode = Mode.baseline
    @State private var sample = Sample.single
    @State private var ready = false
    @State private var replayID = UUID()
    @State private var running = false
    @State private var tour = false
    @State private var nextEventID = 0
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase

    public init(stage: Stage) {
        _fixture = State(initialValue: BattleTransitionLabFixture(stage: stage))
    }

    public var body: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            Picker(selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
            } label: { Text(verbatim: "Mode") }.pickerStyle(.segmented).padding(.horizontal).disabled(tour)
            if ready {
                BattleTransitionLabCanvas(fixture: fixture)
                    .environment(\.balancedFeedbackPreview, mode == .balanced)
                    .id(mode)
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
            Picker(selection: $sample) {
                ForEach(Sample.allCases, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
            } label: { Text(verbatim: "Sample") }.pickerStyle(.segmented).padding(.horizontal).disabled(tour)
            HStack {
                Button { running = true; tour = false; replayID = UUID() } label: { Text(verbatim: "Replay") }
                Button { running = true; tour = true; replayID = UUID() } label: { Text(verbatim: "A/B Tour") }
                Button { tour = false; running = false; replayID = UUID(); fixture.session.feedback.clear() } label: {
                    Text(verbatim: "Stop")
                }
            }.trinketSecondaryActionButton(controlSize: .small).padding(.bottom)
        }
        .environment(fixture.session)
        .environment(fixture.session.spectacle)
        .trinketScreenBackground()
        .navigationTitle(Text(verbatim: "Feedback A/B"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: displayScale) {
            await fixture.session.prepareBattlePresentationAssets(displayScale: displayScale)
            guard !Task.isCancelled else { return }
            ready = true
            running = true
            replayID = UUID()
        }
        .task(id: replayID) {
            guard ready, running, scenePhase == .active else { return }
            fixture.session.feedback.clear()
            if tour {
                for variant in Mode.allCases {
                    mode = variant
                    for sequence in Sample.allCases {
                        sample = sequence
                        await play(sequence)
                        guard !Task.isCancelled else { return }
                    }
                }
                tour = false
            } else {
                await play(sample)
            }
        }
        .onChange(of: mode) { _, _ in
            guard !tour else { return }
            running = true
            replayID = UUID()
        }
        .onChange(of: sample) { _, _ in
            guard !tour else { return }
            running = true
            replayID = UUID()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                running = false; replayID = UUID(); fixture.session.feedback.clear()
            }
        }
        .onDisappear { fixture.session.endBattle() }
    }

    private func play(_ sample: Sample) async {
        let feedback = fixture.session.feedback
        feedback.clear()
        feedback.debugBalancedPreview = mode == .balanced
        feedback.setSuspended(false)
        // Fixed pre-roll makes mode switches and video alignment visible.
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        let count = sample == .single ? 1 : sample == .reactions ? 2 : 6
        for index in 0 ..< count {
            guard !Task.isCancelled else { return }
            feedback.record(events(sample, index: index))
            try? await Task.sleep(for: .milliseconds(140))
        }
        try? await Task.sleep(for: .seconds(sample == .mixed || sample == .corners ? 6 : 4))
    }

    private func events(_ sample: Sample, index: Int) -> [ActionEvent] {
        guard let hero = fixture.session.presentation.hero?.combatant,
              let enemy = fixture.session.presentation.enemy?.combatant else { return [] }
        let group = nextEventID + 1
        var output: [ActionEvent] = []
        func append(_ kind: ActionEvent.Kind, amount: Int = 3, keyword: Keyword, target: Combatant, critical: Bool = false) {
            nextEventID += 1
            output.append(ActionEvent(
                id: nextEventID, actionID: group, kind: kind, actorID: hero.id, actorName: hero.name,
                abilityID: "feedback-ab", abilityName: "Preview", targetID: target.id, targetName: target.name,
                amount: amount, keyword: keyword, isCritical: critical,
            ))
        }
        switch sample {
        case .single, .rapid:
            let keywords: [Keyword] = [.physical, .burn, .freeze, .poison, .holy, .physical]
            append(.abilityDamage, amount: index == 3 ? 18 : 7 + index, keyword: keywords[index], target: enemy, critical: index == 3)
        case .mixed:
            append(.abilityDamage, amount: 7 + index, keyword: index.isMultiple(of: 2) ? .physical : .burn, target: enemy)
            append(.effect(.instantHeal), amount: 4 + index, keyword: .health, target: enemy)
            if index.isMultiple(of: 2) {
                append(.effect(.shieldAbsorbed), amount: 3, keyword: .block, target: enemy)
            }
        case .corners:
            let benefits: [ActionEvent.EffectOutcome] = [.shieldApplied, .thornsApplied, .leechApplied]
            let keywords: [Keyword] = [.block, .thorns, .leech]
            append(.effect(benefits[index % 3]), keyword: keywords[index % 3], target: enemy)
            append(.effect(.recurringDamageApplied), keyword: index.isMultiple(of: 2) ? .poison : .bleed, target: enemy)
        case .reactions:
            append(.reaction(.frostfire), amount: 0, keyword: .burn, target: enemy)
            append(.abilityDamage, amount: 12, keyword: .burn, target: enemy)
            append(.abilityDamage, amount: 8, keyword: .freeze, target: enemy)
        }
        return output
    }
}
#endif
