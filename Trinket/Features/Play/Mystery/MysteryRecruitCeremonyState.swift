import Foundation
import Observation
import SwiftUI
import TrinketDesignSystem

@MainActor
@Observable
final class MysteryRecruitCeremonyState {
    enum Phase: Equatable {
        case veiled
        case unmasking
        case offered
        case sealing
    }

    private(set) var phase: Phase = .veiled
    private(set) var veilAmount = 1.0
    private(set) var bloomOpacity = 0.0
    private(set) var artScale = MysteryCeremonyMotion.veiledArtScale
    private(set) var eyebrowOpacity = 0.0
    private(set) var titleOpacity = 0.0
    private(set) var subtitleOpacity = 0.0
    private(set) var recruitOpacity = 0.0
    private(set) var checkOpacity = 0.0
    private(set) var sealBadgeScale = MysteryCeremonyMotion.sealBadgeStartScale
    private(set) var unmaskFeedbackTrigger = 0
    private(set) var sealFeedbackTrigger = 0

    private var hasStarted = false
    private var task: Task<Void, Never>?
    private var pendingSealComplete: (() -> Void)?

    var isOffered: Bool {
        phase == .offered
    }

    var allowsDetail: Bool {
        phase == .offered
    }

    func start(onUnmaskPeak: @escaping () -> Void) {
        guard !hasStarted else { return }
        hasStarted = true

        task = Task { @MainActor in
            await runUnmaskSequence(onUnmaskPeak: onUnmaskPeak)
        }
    }

    private func runUnmaskSequence(onUnmaskPeak: @escaping () -> Void) async {
        let clock = SuspendingClock()
        try? await clock.sleep(for: .seconds(MysteryCeremonyMotion.veilHold))
        guard !Task.isCancelled else { return }

        phase = .unmasking
        withAnimation(MysteryCeremonyMotion.unmask) {
            veilAmount = 0
            artScale = 1
        }
        withAnimation(MysteryCeremonyMotion.bloomIn) {
            bloomOpacity = MysteryCeremonyMotion.bloomPeakOpacity
        }

        try? await clock.sleep(
            for: .seconds(
                MysteryCeremonyMotion.unmaskResponse * MysteryCeremonyMotion.bloomPeakFraction
            )
        )
        guard !Task.isCancelled else { return }
        onUnmaskPeak()
        unmaskFeedbackTrigger += 1
        withAnimation(MysteryCeremonyMotion.bloomOut) {
            bloomOpacity = 0
        }

        try? await clock.sleep(
            for: .seconds(
                MysteryCeremonyMotion.unmaskResponse * (1 - MysteryCeremonyMotion.bloomPeakFraction)
            )
        )
        guard !Task.isCancelled else { return }
        try? await clock.sleep(for: .seconds(MysteryCeremonyMotion.chromeAfterUnmask))
        guard !Task.isCancelled else { return }
        await presentChrome()
        task = nil
    }

    private func presentChrome() async {
        let clock = SuspendingClock()
        withAnimation(MysteryCeremonyMotion.chrome) {
            eyebrowOpacity = 1
        }
        try? await clock.sleep(for: .seconds(MysteryCeremonyMotion.chromeStagger))
        guard !Task.isCancelled else { return }
        withAnimation(MysteryCeremonyMotion.chrome) {
            titleOpacity = 1
        }
        try? await clock.sleep(for: .seconds(MysteryCeremonyMotion.chromeStagger))
        guard !Task.isCancelled else { return }
        withAnimation(MysteryCeremonyMotion.chrome) {
            subtitleOpacity = 1
        }
        try? await clock.sleep(for: .seconds(MysteryCeremonyMotion.recruitButtonDelay))
        guard !Task.isCancelled else { return }
        withAnimation(MysteryCeremonyMotion.chrome) {
            recruitOpacity = 1
        }
        phase = .offered
    }

    func beginSeal(onComplete: @escaping () -> Void) {
        guard phase == .offered else { return }
        phase = .sealing
        pendingSealComplete = onComplete
        task?.cancel()
        sealFeedbackTrigger += 1

        task = Task { @MainActor in
            let clock = SuspendingClock()
            withAnimation(TrinketMotion.Content.fade) {
                recruitOpacity = 0
                subtitleOpacity = 0
            }
            withAnimation(MysteryCeremonyMotion.seal) {
                checkOpacity = 1
                sealBadgeScale = 1
                artScale = MysteryCeremonyMotion.sealArtPeakScale
            }
            try? await clock.sleep(for: .seconds(MysteryCeremonyMotion.sealArtPeakDelay))
            guard !Task.isCancelled else { return }
            withAnimation(MysteryCeremonyMotion.seal) {
                artScale = 1
            }
            try? await clock.sleep(
                for: .seconds(
                    MysteryCeremonyMotion.sealResponse
                        + MysteryCeremonyMotion.sealHoldBeforeDismiss
                        - MysteryCeremonyMotion.sealArtPeakDelay
                )
            )
            guard !Task.isCancelled else { return }
            finishSeal()
        }
    }

    func cancel() {
        let wasSealing = phase == .sealing
        task?.cancel()
        task = nil
        if wasSealing {
            finishSeal()
            return
        }
        if hasStarted {
            snapToOfferedVisuals()
        }
    }

    private func finishSeal() {
        let complete = pendingSealComplete
        pendingSealComplete = nil
        task = nil
        complete?()
    }

    private func snapToOfferedVisuals() {
        veilAmount = 0
        bloomOpacity = 0
        artScale = 1
        eyebrowOpacity = 1
        titleOpacity = 1
        subtitleOpacity = 1
        recruitOpacity = 1
        phase = .offered
    }
}
