#if DEBUG
import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Xcode Preview lab for recruit invitation breathing shroud → clear portrait.
private struct RecruitRevealMotionLab: View {
    private var subjects: [Combatant] {
        GameContent.heroes + GameContent.companions
    }

    @State private var combatantID = GameContent.heroes.first?.id
        ?? GameContent.companions.first?.id
        ?? ""
    @State private var duration: CGFloat = TrinketMotion.RecruitReveal.revealDuration
    @State private var scrubProgress: CGFloat = 0
    @State private var playsAutomatically = false
    @State private var requiresTapToReveal = true
    @State private var phase: RecruitRevealLabPhase = .invitation
    @State private var revealStart = Date()
    @State private var showsShellChrome = true

    private var combatant: Combatant? {
        subjects.first(where: { $0.id == combatantID })
    }

    private var previewStage: Stage? {
        guard let combatant else { return nil }
        let eventID = combatant.role == .companion ? "recruit-bear" : "recruit-rogue"
        guard let template = GameContent.chapters
            .flatMap(\.stages)
            .first(where: { stage in
                if case let .mysteryEvent(id) = stage.encounter {
                    return id == eventID
                }
                return false
            })
        else {
            return nil
        }
        return template
    }

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.animation) { timeline in
                stage(at: timeline.date)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketScreenBackground()

            Form {
                Section("Subject") {
                    Picker("Combatant", selection: $combatantID) {
                        ForEach(subjects, id: \.id) { subject in
                            Text(subject.name).tag(subject.id)
                        }
                    }
                    Toggle("Reward Shell Chrome", isOn: $showsShellChrome)
                }

                Section("Interaction") {
                    Toggle("Require Tap to Reveal", isOn: $requiresTapToReveal)
                        .onChange(of: requiresTapToReveal) { _, requiresTap in
                            resetPlayback(autoPlay: !requiresTap)
                        }
                    Button("Reset to Invitation") {
                        resetPlayback(autoPlay: false)
                    }
                    .disabled(!requiresTapToReveal && phase == .invitation)
                }

                Section("Playback") {
                    Toggle("Auto-play Reveal", isOn: $playsAutomatically)
                        .disabled(requiresTapToReveal && phase == .invitation)
                        .onChange(of: playsAutomatically) { _, isPlaying in
                            if isPlaying, phase != .invitation || !requiresTapToReveal {
                                beginReveal(from: Date())
                            }
                        }
                    parameterSlider("Duration", value: $duration, range: 0.4 ... 2.8, format: "%.2f s")
                    parameterSlider("Progress", value: $scrubProgress, range: 0 ... 1, format: "%.2f")
                        .disabled(playsAutomatically || (requiresTapToReveal && phase == .invitation))
                    Button("Replay") {
                        if requiresTapToReveal {
                            resetPlayback(autoPlay: false)
                        } else {
                            scrubProgress = 0
                            beginReveal(from: Date())
                            playsAutomatically = true
                        }
                    }
                }

                Section("Notes") {
                    Text(
                        """
                        Invitation shows mystery stage art with a breathing blur/desat. \
                        Tap crossfades into clear recruit art; chrome fades in without moving the art.
                        """
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            // UIStyleCheck: allow - DEBUG preview lab side panel needs a fixed inspector width.
            .frame(width: 360)
        }
        .onChange(of: combatantID) { _, _ in
            resetPlayback(autoPlay: !requiresTapToReveal)
        }
    }

    private func stage(at date: Date) -> some View {
        let progress = revealProgress(at: date)
        return VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Text("Recruit Reveal Lab")
                    .font(.title2.weight(.bold))
                Text(phaseTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let combatant, let previewStage {
                RecruitRevealEffectPreview(
                    stage: previewStage,
                    combatant: combatant,
                    phase: phase,
                    progress: progress,
                    showsShellChrome: showsShellChrome,
                    onInviteTap: {
                        beginReveal(from: Date())
                    }
                )
                .frame(maxWidth: 420)
                .onChange(of: progress) { _, value in
                    guard phase == .revealing, playsAutomatically, value >= 1 else { return }
                    phase = .complete
                    scrubProgress = 1
                }
            } else {
                ContentUnavailableView("No Combatant", systemImage: "person.crop.rectangle")
            }

            Text(statusLine(progress: progress))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(TrinketDesign.Metrics.extraLargeSpacing)
    }

    private var phaseTitle: String {
        switch phase {
        case .invitation: "breathing · invitation"
        case .revealing: "clearing · revealing"
        case .complete: "clear · complete"
        }
    }

    private func statusLine(progress: CGFloat) -> String {
        switch phase {
        case .invitation:
            "blur \(Int(TrinketMotion.RecruitReveal.invitationBlurMin))…\(Int(TrinketMotion.RecruitReveal.invitationBlurMax))"
        case .revealing, .complete:
            String(format: "t = %.2f", progress)
        }
    }

    private func revealProgress(at date: Date) -> CGFloat {
        switch phase {
        case .invitation:
            return 0
        case .revealing, .complete:
            if !playsAutomatically {
                return scrubProgress
            }
            if phase == .complete {
                return 1
            }
            let elapsed = max(0, date.timeIntervalSince(revealStart))
            return CGFloat(min(1, elapsed / TimeInterval(duration)))
        }
    }

    private func beginReveal(from date: Date) {
        revealStart = date
        scrubProgress = 0
        phase = .revealing
        playsAutomatically = true
    }

    private func resetPlayback(autoPlay: Bool) {
        scrubProgress = 0
        revealStart = Date()
        playsAutomatically = autoPlay
        phase = autoPlay ? .revealing : .invitation
    }

    private func parameterSlider(
        _ title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        format: String
    ) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, value.wrappedValue))
            Slider(value: value, in: range)
        }
    }
}

#Preview("Recruit Reveal Motion Lab") {
    RecruitRevealMotionLab()
}
#endif
