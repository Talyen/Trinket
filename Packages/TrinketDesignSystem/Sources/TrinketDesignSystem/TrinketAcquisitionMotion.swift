import SwiftUI

public extension View {
    func trinketExceptionalLootMotion(trigger: Int, isActive: Bool = true) -> some View {
        modifier(AcquisitionMotionModifier(
            trigger: trigger, isActive: isActive,
            initialScale: TrinketMotion.Reward.exceptionalInitialScale,
            peakScale: TrinketMotion.Reward.exceptionalPeakScale,
            riseDuration: TrinketMotion.Reward.exceptionalRiseDuration,
            settleDuration: TrinketMotion.Reward.exceptionalSettleDuration,
        ))
    }

    func trinketPurchaseMotion(trigger: Int, isActive: Bool = true) -> some View {
        modifier(AcquisitionMotionModifier(
            trigger: trigger, isActive: isActive, initialScale: 1,
            peakScale: TrinketMotion.Interaction.purchasePeakScale,
            riseDuration: TrinketMotion.Interaction.purchaseRiseDuration,
            settleDuration: TrinketMotion.Interaction.purchaseSettleDuration,
        ))
    }
}

private struct AcquisitionMotionModifier: ViewModifier {
    let trigger: Int
    let isActive: Bool
    let initialScale: CGFloat
    let peakScale: CGFloat
    let riseDuration: TimeInterval
    let settleDuration: TimeInterval
    @State private var scale: CGFloat = 1
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                cancel()
                guard isActive else { return }
                scale = initialScale
                task = Task { @MainActor in
                    // Let the initial pose publish before starting the arrival.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: riseDuration)) { scale = peakScale }
                    do { try await Task.sleep(for: .seconds(riseDuration)) } catch { return }
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: settleDuration)) { scale = 1 }
                    task = nil
                }
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    cancel()
                }
            }
            .onDisappear { cancel() }
    }

    private func cancel() {
        guard task != nil || scale != 1 else { return }
        task?.cancel()
        task = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { scale = 1 }
    }
}
