enum CombatGain {
    static func amount(_ requested: Int, current: Int, cap: Int) -> Int {
        min(max(0, requested), max(0, cap - current))
    }
}
