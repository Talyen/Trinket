/// Reporting goals apply to every loadout tier and advancing progression encounter.
enum BalanceEncounterTargets {
    static func winBand(isBoss: Bool) -> (lower: Double, upper: Double) {
        isBoss ? (0.70, 0.90) : (0.90, 0.98)
    }

    static var winGoalDescription: String {
        let normal = winBand(isBoss: false)
        let boss = winBand(isBoss: true)
        return "regular enemies `\(Int(normal.lower * 100))-\(Int(normal.upper * 100))%`, "
            + "bosses `\(Int(boss.lower * 100))-\(Int(boss.upper * 100))%` (all tiers)"
    }
}
