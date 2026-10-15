import BattleEngine
import SwiftUI
import TrinketFeatureSupport

public struct BattleLogSheet: View {
    @Environment(\.locale) private var locale
    let entries: [LogEntry]

    public init(entries: [LogEntry]) {
        self.entries = entries
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(String(localized: L10n.ui_battlelogsheet_battle_log_eb70a)) {
                    ForEach(entries) { entry in
                        Text(verbatim: entry.localizedText(locale: locale))
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Battle.combatLogSheet)
            .navigationTitle(Text(L10n.ui_battlelogsheet_combat_log_84d6c))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
