import BattleEngine
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

public struct BattleLogSheet: View {
    @Environment(\.locale) private var locale
    let entries: [LogEntry]

    public init(entries: [LogEntry]) {
        self.entries = entries
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(L10n.ui_battlelogsheet_battle_log_eb70a)
                        .trinketTypography(.cardTitle)
                        .accessibilityAddTraits(.isHeader)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, TrinketDesign.Spacing.small)
                    ForEach(entries) { entry in
                        Text(verbatim: entry.localizedText(locale: locale))
                            .trinketTypography(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, TrinketDesign.Spacing.small)
                        Divider()
                    }
                }
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.vertical, TrinketDesign.Spacing.large)
            }
            .accessibilityIdentifier(AccessibilityID.Battle.combatLogSheet)
            .navigationTitle(Text(L10n.ui_battlelogsheet_combat_log_84d6c))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
