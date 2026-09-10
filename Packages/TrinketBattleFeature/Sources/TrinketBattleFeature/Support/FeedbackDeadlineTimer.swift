import Foundation

@MainActor
final class FeedbackDeadlineTimer {
    private var timer: Timer?
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
                self.onFire()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    isolated deinit {
        timer?.invalidate()
    }
}
