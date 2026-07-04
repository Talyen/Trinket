# Type Safety Density Audit

Goal: Drive unsafe typing escapes toward zero in non-test source.

## Targets

- `rg -n '\bAny\b' --type swift -g '!*Tests*' -g '!*UITests*'` — target trending to 0 in model/rule code; existential `any` protocol is fine
- `rg -n 'as!' --type swift -g '!*Tests*' -g '!*UITests*'` — target 0
- `rg -n 'try!' --type swift -g '!*Tests*'` — target 0 in non-test, non-generated source
- `rg -n 'Force Unwrap|IUO|implicitly unwrapped' --type swift -g '!*Tests*'` — target 0
- `rg -n 'swiftlint:disable' --type swift -g '!*Tests*'` — target trending to 0

## Checks

- Replace `as!` with `as?` + `guard`/`if let`, or redesign types to avoid the downcast
- Replace `try!` with proper error handling (`do/catch`, `Result`, throwing `init?`)
- Replace force unwraps (`!`) with `guard let`, `if let`, or optional chaining
- Remove `// swiftlint:disable` by fixing the violation; surviving disables must be line-scoped with a reason comment
- Use `Any` only at Clearance/save-load boundaries with `Codable` or `NSCoding`; prefer `any SomeProtocol` (existentials) elsewhere
- Keep `Codable`/`JSONEncoder`/`JSONDecoder` at persistence boundaries; validate with `init(from:)` throws, not runtime casts
