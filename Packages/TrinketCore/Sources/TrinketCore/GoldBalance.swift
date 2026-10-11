/// Shared wallet bounds for saved Gold, rewards, and Homestead production.
public enum GoldBalance {
    public static let maximum = 999

    public static func clamped(_ amount: Int) -> Int {
        min(max(amount, 0), maximum)
    }
}
