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
    private(set) var artScale = TrinketMotion.Mystery.veiledArtScale
    private(set) var eyebrowOpacity = 0.0
    private(set) var titleOpacity = 0.0
    private(set) var subtitleOpacity = 0.0
    private(set) var recruitOpacity = 0.0
    private(set) var checkOpacity = 0.0
    private(set) var sealBadgeScale = TrinketMotion.Mystery.sealBadgeStartScale
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

    func start(reduceMotion: Bool, onUnmaskPeak: @escaping () -> Void) {
        guard !hasStarted else { return }
        hasStarted = true
        if reduceMotion {
            withAnimation(TrinketMotion.Content.fade) {
                snapToOfferedVisuals()
            }
            onUnmaskPeak()
            unmaskFeedbackTrigger += 1
            return
        }

        task = Task { @MainActor in
            await runUnmaskSequence(onUnmaskPeak: onUnmaskPeak)
        }
    }

    private func runUnmaskSequence(onUnmaskPeak: @escaping () -> Void) async {
        let clock = SuspendingClock()
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.veilHold))
        guard !Task.isCancelled else { return }

        phase = .unmasking
        withAnimation(TrinketMotion.Mystery.unmask) {
            veilAmount = 0
            artScale = 1
        }
        withAnimation(TrinketMotion.Mystery.bloomIn) {
            bloomOpacity = TrinketMotion.Mystery.bloomPeakOpacity
        }

        try? await clock.sleep(
            for: .seconds(
                TrinketMotion.Mystery.unmaskResponse * TrinketMotion.Mystery.bloomPeakFraction
            )
        )
        guard !Task.isCancelled else { return }
        onUnmaskPeak()
        unmaskFeedbackTrigger += 1
        withAnimation(TrinketMotion.Mystery.bloomOut) {
            bloomOpacity = 0
        }

        try? await clock.sleep(
            for: .seconds(
                TrinketMotion.Mystery.unmaskResponse * (1 - TrinketMotion.Mystery.bloomPeakFraction)
            )
        )
        guard !Task.isCancelled else { return }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.chromeAfterUnmask))
        guard !Task.isCancelled else { return }
        await presentChrome()
        task = nil
    }

    private func presentChrome() async {
        let clock = SuspendingClock()
        withAnimation(TrinketMotion.Mystery.chrome) {
            eyebrowOpacity = 1
        }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.chromeStagger))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Mystery.chrome) {
            titleOpacity = 1
        }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.chromeStagger))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Mystery.chrome) {
            subtitleOpacity = 1
        }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.recruitButtonDelay))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Mystery.chrome) {
            recruitOpacity = 1
        }
        phase = .offered
    }

    func beginSeal(reduceMotion: Bool, onComplete: @escaping () -> Void) {
        guard phase == .offered else { return }
        phase = .sealing
        pendingSealComplete = onComplete
        task?.cancel()
        sealFeedbackTrigger += 1
        if reduceMotion {
            task = Task { @MainActor in
                let clock = SuspendingClock()
                withAnimation(TrinketMotion.Content.fade) {
                    applySealedVisuals()
                }
                try? await clock.sleep(
                    for: .seconds(
                        TrinketMotion.Content.fadeDuration
                            + TrinketMotion.Mystery.sealHoldBeforeDismiss
                    )
                )
                guard !Task.isCancelled else { return }
                finishSeal()
            }
            return
        }

        task = Task { @MainActor in
            let clock = SuspendingClock()
            withAnimation(TrinketMotion.Content.fade) {
                recruitOpacity = 0
                subtitleOpacity = 0
            }
            withAnimation(TrinketMotion.Mystery.seal) {
                checkOpacity = 1
                sealBadgeScale = 1
                artScale = TrinketMotion.Mystery.sealArtPeakScale
            }
            try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.sealArtPeakDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Mystery.seal) {
                artScale = 1
            }
            try? await clock.sleep(
                for: .seconds(
                    TrinketMotion.Mystery.sealResponse
                        + TrinketMotion.Mystery.sealHoldBeforeDismiss
                        - TrinketMotion.Mystery.sealArtPeakDelay
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

    private func applySealedVisuals() {
        recruitOpacity = 0
        subtitleOpacity = 0
        checkOpacity = 1
        sealBadgeScale = 1
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
