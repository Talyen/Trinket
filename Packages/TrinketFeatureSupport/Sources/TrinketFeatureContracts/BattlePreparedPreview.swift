import BattleEngine

/// An application-owned preparation. Its simulation remains private to the creating runtime.
@MainActor
public protocol PreparedBattleRunHandle: AnyObject {
    var configuration: BattleRunConfiguration { get }
    func invalidate()
}

/// Read-only preparation projection for overlay selection and artwork pins.
@MainActor
public struct BattlePreparedPreview {
    public let configurations: [BattleRunConfiguration]
    public let selected: (any PreparedBattleRunHandle)?

    public init(configurations: [BattleRunConfiguration], selected: (any PreparedBattleRunHandle)?) {
        self.configurations = configurations
        self.selected = selected
    }

    public static var empty: Self {
        Self(configurations: [], selected: nil)
    }
}
