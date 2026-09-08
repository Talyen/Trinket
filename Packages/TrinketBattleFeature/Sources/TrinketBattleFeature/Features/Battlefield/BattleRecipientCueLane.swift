import SwiftUI
import TrinketDesignSystem

enum BattleCardCueMotion {
    static let arrival = Animation.easeOut(duration: 0.09)
    static let cancellation = Animation.easeOut(duration: 0.16)
    static let completion = Animation.easeOut(duration: 0.22)
    static let lightOpacity = 0.20
    static let travel: CGFloat = 3
    static let deniedBlinkCount = 2
    static let deniedBlinkInterval: Duration = .milliseconds(90)
}

struct BattleRecipientCueLane<Content: View>: View {
    @Environment(BattleSession.self) private var battleSession
    let combatantID: String
    @ViewBuilder let content: () -> Content

    @State private var recipient: BattleRecipientCue?
    @State private var strength: CGFloat = 0

    var body: some View {
        let cue = battleSession.cardCues.current
        content()
            .overlay {
                if let recipient, recipient.kind != .deniedHealth {
                    cueLight(for: recipient)
                        .opacity(Double(strength) * BattleCardCueMotion.lightOpacity)
                        .clipShape(TrinketDesign.cardShape)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(x: scaleX, y: scaleY)
            .offset(y: offsetY)
            .task(id: cue) {
                await adopt(cue)
            }
    }

    @ViewBuilder
    private func cueLight(for recipient: BattleRecipientCue) -> some View {
        let color = recipient.keyword?.visualStyle.color ?? TrinketDesign.Colors.accent
        switch recipient.kind {
        case .attack:
            RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: 110)
                .scaleEffect(1.15 - strength * 0.15)
        case .restore, .gain:
            LinearGradient(colors: [.clear, color, .clear], startPoint: .top, endPoint: .bottom)
                .offset(y: (1 - strength) * 12)
        case .protect, .deniedControl:
            ZStack {
                LinearGradient(colors: [.clear, color], startPoint: .top, endPoint: .bottom)
                TrinketDesign.cardShape.stroke(color, lineWidth: 2)
            }
        case .cleanse:
            RadialGradient(colors: [.clear, color, .clear], center: .center, startRadius: 10, endRadius: 120)
                .scaleEffect(0.8 + strength * 0.2)
        case .prepare:
            RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: 160)
        case .deniedDefeated:
            TrinketDesign.cardShape.stroke(TrinketDesign.Colors.Overlay.paper, lineWidth: 2)
        case .deniedHealth:
            Color.clear
        }
    }

    private var scaleX: CGFloat {
        guard let kind = recipient?.kind else { return 1 }
        return [.protect, .deniedControl].contains(kind) ? 1 + strength * 0.006 : 1
    }

    private var scaleY: CGFloat {
        guard let kind = recipient?.kind else { return 1 }
        return [.protect, .deniedControl].contains(kind) ? 1 - strength * 0.01 : 1
    }

    private var offsetY: CGFloat {
        switch recipient?.kind {
        case .restore, .prepare: -strength * BattleCardCueMotion.travel
        case .gain: strength * BattleCardCueMotion.travel
        default: 0
        }
    }

    private func adopt(_ cue: BattleCardCue?) async {
        guard let cue, let next = cue.recipients[combatantID] else {
            withAnimation(BattleCardCueMotion.cancellation) { strength = 0 }
            return
        }
        recipient = next
        switch cue.phase {
        case .lifted:
            withAnimation(BattleCardCueMotion.arrival) { strength = 1 }
        case .committed:
            withAnimation(BattleCardCueMotion.completion) { strength = 0 }
        case .denied:
            for _ in 0 ..< BattleCardCueMotion.deniedBlinkCount {
                withAnimation(BattleCardCueMotion.arrival) { strength = 1 }
                try? await Task.sleep(for: BattleCardCueMotion.deniedBlinkInterval)
                guard !Task.isCancelled else { return }
                withAnimation(BattleCardCueMotion.arrival) { strength = 0 }
                try? await Task.sleep(for: BattleCardCueMotion.deniedBlinkInterval)
                guard !Task.isCancelled else { return }
            }
        }
    }
}
