import CoreMotion
import SwiftUI

@Observable
final class MotionObserver {
    private let manager = CMMotionManager()
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let maxOffset: CGFloat = 12

            // Raw attitude roll and pitch values
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch

            // Manual clamping for safety
            let clampedRoll = max(min(roll, 1.5), -1.5)
            let clampedPitch = max(min(pitch, 1.5), -1.5)

            withAnimation(.easeOut(duration: 0.1)) {
                self.xOffset = CGFloat(clampedRoll) * maxOffset
                self.yOffset = CGFloat(clampedPitch) * maxOffset
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
