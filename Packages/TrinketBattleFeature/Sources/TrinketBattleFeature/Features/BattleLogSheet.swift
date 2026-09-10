import BattleEngine
import SwiftUI
import TrinketFeatureSupport

public struct BattleLogSheet: View {
    let entries: [LogEntry]

    public init(entries: [LogEntry]) {
        self.entries = entries
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Battle Log") {
                    ForEach(entries) { entry in
                        Text(entry.text)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Battle.combatLogSheet)
            .navigationTitle("Combat Log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
