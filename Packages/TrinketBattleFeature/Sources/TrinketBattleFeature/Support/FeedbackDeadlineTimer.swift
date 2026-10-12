import Foundation
import TrinketCore

@MainActor
final class FeedbackDeadlineTimer {
    private var timer: Timer?
    private var cleanup: MainActorCleanup?
    private let onFire: () -> Void

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
    }

    func schedule(at date: Date?) {
        guard timer?.fireDate != date else { return }
        cancel()
        guard let date else { return }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.timer = nil
                self.cleanup = nil
                self.onFire()
            }
        }
        self.timer = timer
        cleanup = MainActorCleanup { timer.invalidate() }
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancel() {
        cleanup = nil
        timer = nil
    }
}
