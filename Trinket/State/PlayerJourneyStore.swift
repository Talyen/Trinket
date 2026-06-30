import Foundation
import SwiftUI

@Observable
final class PlayerJourneyStore {
    private static let storageKey = "PlayerJourneyStore.current"

    private let defaults: UserDefaults
    var current: JourneyProgressState {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(JourneyProgressState.self, from: data) {
            current = decoded
        } else {
            current = .initial
        }
    }

    func complete(_ stage: Stage, in chapters: [Chapter]) {
        current.complete(stage, in: chapters)
    }

    func markRewardsClaimed(for stage: Stage) {
        current.markRewardsClaimed(for: stage)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(current) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
