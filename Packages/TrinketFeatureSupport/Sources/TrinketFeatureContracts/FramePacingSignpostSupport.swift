import os
import SwiftUI

public enum FramePacingSignpostSupport {
    public static let subsystem = "com.trinket.framepacing"

    public static func event(log: OSLog, name: StaticString, detail: String) {
        os_signpost(
            .event,
            log: log,
            name: name,
            "%{public}@",
            detail as NSString,
        )
    }
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

public extension View {
    func framePacingInterval(signposter: OSSignposter, name: StaticString, isActive: Bool) -> some View {
        modifier(FramePacingIntervalModifier(signposter: signposter, name: name, isActive: isActive))
    }
}
