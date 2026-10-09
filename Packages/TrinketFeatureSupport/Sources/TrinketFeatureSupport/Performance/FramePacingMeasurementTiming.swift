import Foundation
import os
import SwiftUI

public enum FramePacingMeasurementTiming {
    public static let isQuick =
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-battle-performance-quick")

    public static var monitorWarmupSeconds: TimeInterval {
        isQuick ? 0.35 : 0.75
    }
}

public enum FramePacingMeasurementControl {
    public static let reset = Notification.Name("Trinket.FramePacing.Reset")
    public static let finished = Notification.Name("Trinket.FramePacing.Finished")
    public static let begin = Notification.Name("Trinket.FramePacing.Begin")
}

public struct FramePacingIntervalModifier: ViewModifier {
    let signposter: OSSignposter
    let name: StaticString
    let isActive: Bool

    @State private var intervalState: OSSignpostIntervalState?

    public init(signposter: OSSignposter, name: StaticString, isActive: Bool) {
        self.signposter = signposter
        self.name = name
        self.isActive = isActive
    }

    public func body(content: Content) -> some View {
        content
            .onChange(of: isActive, initial: true) { _, active in
                if active {
                    beginIfNeeded()
                } else {
                    endIfNeeded()
                }
            }
            .onDisappear {
                endIfNeeded()
            }
    }

    private func beginIfNeeded() {
        guard intervalState == nil else { return }
        intervalState = signposter.beginInterval(name)
    }

    private func endIfNeeded() {
        guard let intervalState else { return }
        signposter.endInterval(name, intervalState)
        self.intervalState = nil
    }
}
