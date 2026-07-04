import TrinketContent

extension Enemy {
    static var randomNormalCombatant: Combatant {
        let normals = GameContent.enemies.filter { !$0.isBoss }
        if let enemy = normals.randomElement()?.combatant {
            return enemy
        }
        return GameContent.enemies.first?.combatant ?? fallbackCombatant
    }
}
