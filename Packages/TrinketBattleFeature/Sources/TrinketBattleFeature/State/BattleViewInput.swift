/// A view's commands belong to the display it captured. Retiring displays stay
/// visible, but lose permission to change the runtime as soon as it replaces them.
@MainActor
struct BattleViewInput {
    private weak var session: BattleSession?
    private let presentation: BattlePresentationState

    init(session: BattleSession, presentation: BattlePresentationState) {
        self.session = session
        self.presentation = presentation
    }

    func isCurrent(in session: BattleSession) -> Bool {
        self.session === session && session.presentation === presentation
            && session.activeBattle != nil
    }

    var isCurrent: Bool {
        guard let session else { return false }
        return isCurrent(in: session)
    }

    @discardableResult
    func perform<Value>(_ action: (BattleSession) -> Value) -> Value? {
        guard let session, isCurrent(in: session) else { return nil }
        return action(session)
    }
}
