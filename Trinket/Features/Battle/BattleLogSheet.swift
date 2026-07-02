import SwiftUI

struct BattleLogSheet: View {
    @Environment(\.dismiss) private var dismiss

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
            .navigationTitle("Combat Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
