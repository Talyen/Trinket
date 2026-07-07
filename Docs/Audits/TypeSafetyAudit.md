# Type Safety Density Audit

Goal: Drive unsafe typing escapes toward zero in non-test source.

## Targets

- `rg -n '\bAny\b' --type swift -g '!*Tests*' -g '!*UITests*' .` — target trending to 0 in model/rule code; existential `any` protocol is fine
- `rg -n 'as!' --type swift -g '!*Tests*' -g '!*UITests*' .` — target 0
- `rg -n 'try!' --type swift -g '!*Tests*' .` — target 0 in non-test, non-generated source
- `rg -n 'Force Unwrap|IUO|implicitly unwrapped' --type swift -g '!*Tests*' .` — target 0
- `rg -n 'swiftlint:disable' --type swift -g '!*Tests*' .` — target trending to 0

## Checks

### Force Casting & Unwrapping Refactoring Patterns

#### Force Cast (`as!`)
* **Bad**: `let cell = item as! HeroCell`
* **Good**: 
  ```swift
  guard let cell = item as? HeroCell else {
      logger.error("Invalid cell item type: \(type(of: item))")
      return
  }
  ```

#### Force Unwrapping (`!`)
* **Bad**: `let name = combatant.name!`
* **Good**: `let name = combatant.name ?? "Unknown"` or `guard let name = combatant.name else { ... }`

#### Force Try (`try!`)
* **Bad**: `let data = try! JSONEncoder().encode(save)`
* **Good**:
  ```swift
  do {
      let data = try JSONEncoder().encode(save)
  } catch {
      logger.error("Failed to encode save: \(error.localizedDescription)")
  }
  ```

### Safe SwiftUI Environment Isolation
- Audit usage of `@EnvironmentObject` which will crash at runtime if the object is missing from the parent view context.
- Prefer defining modern `@Environment` keys with a safe default value, or wrap in a fallback structure to prevent runtime crashes.
- Avoid using `// swiftlint:disable` wherever possible; if a disable is required, scope it strictly to a single line with an explicit reason comment.
- Use `Any` only at serialization/JSON boundaries; prefer existentials (`any MyProtocol`) for dynamic interface variables.
- Validate incoming decoded save payload structures using `init(from:)` checks in [PlayerSaveSanitizer.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveSanitizer.swift) rather than relying on structural runtime casts.
