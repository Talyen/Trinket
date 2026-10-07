/// Exact half-Health comparisons without overflowing doubled Health or rounding through Double.
enum HealthThreshold {
    static func isBelowHalf(_ health: Int, maximum: Int) -> Bool {
        let half = maximum / 2
        return health < half || health == half && maximum % 2 > 0
    }

    static func isAboveHalf(_ health: Int, maximum: Int) -> Bool {
        let half = maximum / 2
        return health > half || health == half && maximum % 2 < 0
    }
}
