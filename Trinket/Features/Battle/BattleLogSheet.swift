import BattleEngine
import SwiftUI

struct BattleLogSheet: View {
    let entries: [LogEntry]

    var body: some View {
        NavigationStack {
            List {
                Section("Battle Log") {
                    ForEach(entries) { entry in
                        Text(entry.text)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Battle.combatLog)
            .navigationTitle("Combat Log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
