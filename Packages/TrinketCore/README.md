# TrinketCore

Domain primitives shared across all Trinket packages. No UIKit/SwiftUI dependencies.
Keep this package independent of the app and feature UI.

Owns effects and keywords, stats and combat rounding, progression and enemy power
curves, homestead resource/node types, and deterministic RNG. Imported by every other
package. Keep dependencies here at zero.

```sh
./Scripts/test-package.sh TrinketCore
```
