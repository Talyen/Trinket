import SwiftUI

public extension View {
    @ViewBuilder
    func trinketAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    func trinketSensoryFeedback(_ feedback: SensoryFeedback, trigger: some Equatable, enabled: Bool) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }

    @ViewBuilder
    func optionalMatchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
