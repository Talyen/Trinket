import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
// DEBUG playground host — production motion lives in `TrinketMotion.Battle` and
// feature config types (Do not ship lab UI).

/// Shared chrome and controls for the DEBUG motion labs.
enum BattleLab {
    /// Shared stage title header.
    struct Title: View {
        let title: String
        let subtitle: String

        var body: some View {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func parameterSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, value.wrappedValue))
            Slider(value: value, in: range)
        }
    }

    static func parameterSlider(
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

    /// Subject picker over authored enemies, shared by the enemy-card preview labs.
    static func enemyPicker(_ selection: Binding<String>) -> some View {
        Picker("Enemy", selection: selection) {
            ForEach(GameContent.enemies, id: \.id) { enemy in
                Text(enemy.name).tag(enemy.id)
            }
        }
    }

    /// Card chrome (artwork + health bar + border) used as a lab preview stage.
    static func combatantCard(_ combatant: Combatant) -> some View {
        ZStack(alignment: .bottom) {
            CombatantArtwork(combatant: combatant, variant: .battle)
            CombatHealthBar(
                health: 72,
                maxHealth: 100,
                fillColor: TrinketDesign.Colors.battleHealth,
                style: .battleBorder,
                height: TrinketDesign.Metrics.battleHealthBarHeight
            )
        }
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
        }
    }
}

/// Single entry point presenting every DEBUG battle motion lab behind a picker.
struct BattleMotionLabHub: View {
    enum Lab: String, CaseIterable, Identifiable {
        case float
        case hand
        case hitReaction
        case enemyAttack

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .float: "Float"
            case .hand: "Hand"
            case .hitReaction: "Hit Reaction"
            case .enemyAttack: "Enemy Attack"
            }
        }
    }

    @State private var selectedLab: Lab = .float

    var body: some View {
        VStack(spacing: 0) {
            Picker("Motion lab", selection: $selectedLab) {
                ForEach(Lab.allCases) { lab in
                    Text(lab.title).tag(lab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, TrinketDesign.Metrics.denseSpacing)

            Group {
                switch selectedLab {
                case .float: CombatFeedbackFloatMotionLab()
                case .hand: HandMotionPlayground()
                case .hitReaction: BattleHitReactionMotionLab()
                case .enemyAttack: BattleEnemyAttackMotionLab()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct BattleMotionLabHub_Previews: PreviewProvider {
    static var previews: some View {
        BattleMotionLabHub()
            .previewDevice(PreviewDevice(rawValue: "iPad Pro 13-inch (M5)"))
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Battle Motion Labs")
    }
}
#endif
