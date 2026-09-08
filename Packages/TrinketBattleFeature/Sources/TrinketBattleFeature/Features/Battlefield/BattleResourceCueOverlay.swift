import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct BattleResourceCueOverlay: View {
    @Environment(BattleSession.self) private var battleSession
    let combatantID: String
    let keyword: Keyword

    @State private var use: BattleCardAssessment.ResourceUse?
    @State private var strength = 0.0
    @State private var isDenied = false

    var body: some View {
        let cue = battleSession.cardCues.current
        GeometryReader { geometry in
            if isDenied {
                Rectangle()
                    .fill(TrinketDesign.Colors.Overlay.paper)
                    .opacity(strength * 0.6)
            } else if let use {
                let start = use.amount.map { max(0, use.balance - $0) } ?? 0
                let end = use.balance
                let capacity = max(1, use.capacity)
                Rectangle()
                    .fill(TrinketDesign.Colors.Overlay.paper)
                    .frame(width: geometry.size.width * min(1, Double(max(0, end - start)) / Double(capacity)))
                    .offset(x: geometry.size.width * min(1, Double(start) / Double(capacity)))
                    .opacity(strength * (use.amount == nil ? 0.25 : 0.5))
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: cue) { await adopt(cue) }
    }

    private func adopt(_ cue: BattleCardCue?) async {
        guard let cue else {
            withAnimation(BattleCardCueMotion.cancellation) { strength = 0 }
            return
        }
        if cue.phase == .denied,
           keyword == .health, cue.recipients[combatantID]?.kind == .deniedHealth {
            isDenied = true
            for _ in 0 ..< BattleCardCueMotion.deniedBlinkCount {
                withAnimation(BattleCardCueMotion.arrival) { strength = 1 }
                try? await Task.sleep(for: BattleCardCueMotion.deniedBlinkInterval)
                guard !Task.isCancelled else { return }
                withAnimation(BattleCardCueMotion.arrival) { strength = 0 }
                try? await Task.sleep(for: BattleCardCueMotion.deniedBlinkInterval)
                guard !Task.isCancelled else { return }
            }
            return
        }
        guard let next = cue.resources.first(where: { $0.combatantID == combatantID && $0.keyword == keyword }) else {
            withAnimation(BattleCardCueMotion.cancellation) { strength = 0 }
            return
        }
        isDenied = false
        use = next
        withAnimation(cue.phase == .committed ? BattleCardCueMotion.completion : BattleCardCueMotion.arrival) {
            strength = cue.phase == .lifted ? 1 : 0
        }
    }
}
