# Performance, Memory & Battery Audit

Goal: Optimize application performance, prevent memory leaks, manage SwiftData thread limits, and reduce battery consumption to ensure a smooth, stable, and energy-efficient experience.

## Targets

- `rg -n '\bAnyView\b' --type swift -g '!*Tests*' .` — target trending to 0; `AnyView` disables SwiftUI layout optimizations and causes unnecessary redraws.
- `rg -n 'var\s+\w+Delegate\s*:\s*(any\s+)?\w+' --type swift -g '!*Tests*' .` — audit delegates to ensure they are marked `weak` (using `weak var delegate: (any Delegate)?`) to avoid retain cycles.
- `rg -n 'NotificationCenter\.default\.addObserver|notifications\(named:\)' --type swift -g '!*Tests*' .` — verify observers or AsyncSequence notification streams are unregistered, invalidated, or cancelled to prevent memory retention.
- `rg -n 'Timer\.scheduledTimer|Timer\.publish' --type swift -g '!*Tests*' .` — check timer frequencies; prefer modern Swift Clocks (`ContinuousClock` / `SuspendingClock`) with `Task.sleep` for periodic logic.
- `rg -n 'ModelContext\b|@Model\b' --type swift -g '!*Tests*' .` — ensure SwiftData models are not shared across concurrency boundaries, and context mutations are offloaded to background actors or tasks.
- Audit battle tick interval values (`BattleSession.swift`) to ensure background states do not spin at excessive rates.

## Checks

### 1. Memory Management & Leak Prevention

#### Retain Cycles in Closures
* **Bad**:
  ```swift
  someService.fetchData { data in
      self.updateUI(with: data) // Retains self
  }
  ```
* **Good**:
  ```swift
  someService.fetchData { [weak self] data in
      guard let self else { return }
      self.updateUI(with: data)
  }
  ```

#### Strong Delegate References
* **Bad**:
  ```swift
  protocol BattleDelegate: AnyObject, Sendable { ... }
  class BattleSimulator {
      var delegate: (any BattleDelegate)? // Strong reference and missing existential keyword
  }
  ```
* **Good**:
  ```swift
  class BattleSimulator {
      weak var delegate: (any BattleDelegate)?
  }
  ```

#### SwiftData Concurrency & Context Confining
* **Bad**: Passing a `@Model` object across Task/Actor boundaries.
  ```swift
  Task.detached {
      let name = heroModel.name // Crash or Data Race (heroModel is not Sendable)
  }
  ```
* **Good**: Query model properties on the isolated context, or pass the model's identifier:
  ```swift
  let heroID = heroModel.persistentIdentifier
  Task.detached {
      // Query hero inside isolated background ModelContext using heroID
  }
  ```

### 2. Rendering & SwiftUI Performance
- **Avoid AnyView**: Prefer `@ViewBuilder`, standard conditionals, or generics to keep view hierarchies statically typed and eligible for fast diffing.
- **Minimizing State Changes**: Group states to prevent parent view updates from triggering redundant redraws in deep descendant hierarchies.
- **Main Thread Offloading**: Ensure disk decoding/encoding of saves (`PlayerSaveStore`), game content parsing (`GameContent`), and pathfinding or simulation calculations happen off the `@MainActor`.
- **Decoupled Game Loop**: Ensure core simulation ticks do not rely on SwiftUI rendering frames (e.g. avoid `TimelineView` for business logic). Move loop processing to background tasks.

### 3. Energy & Battery Optimization
- **Background Pause**: Verify that all battle ticks, UI animations, and active timers are paused or throttled when the app enters `ScenePhase.background`.
- **Modern Clock Coalescing**: Use `SuspendingClock` for timers that should halt when the device is asleep. Apply `tolerance` to Task sleep operations (`try? await Task.sleep(for: .seconds(1), tolerance: .milliseconds(100), clock: .suspending)`) to conserve CPU wakeups.
- **Resource Deallocation**: Confirm that temporary assets, loaded images, and heavy caches are evicted on `didReceiveMemoryWarningNotification` or during phase transitions.

## Fixes

- Refactor strong closures (`self`) to use weak captures (`[weak self]`).
- Clean up SwiftUI hierarchies by replacing `AnyView` wrapper returns with generic views or `@ViewBuilder` decorators.
- Relocate synchronous disk I/O and CPU-bound simulation loops to background dispatch queues or non-isolated Tasks.
- Validate that timers and notification observers are properly invalidated and cleared during object deinitialization.
- Convert legacy `Timer` instances to modern structured concurrent `Task` loop blocks with `Clock` sleep intervals.

## Profiling Recipes

### 1. Checking for Memory Leaks & Retain Cycles
1. Open Trinket in Xcode.
2. Press `⌘+I` to open **Product > Profile**.
3. Select the **Leaks** template in Instruments.
4. Interact with the tabs (Homestead ⇄ Play ⇄ Collection), start/end battles, and examine the lifecycle graph for red leak markers.

### 2. Investigating Main Thread Hangs
1. Select the **Time Profiler** template in Instruments.
2. Record active battles and fast tab switches.
3. Check the **Thread Joins** or **Hang Detector** lane to see if the main thread is blocked by save persistence writes (`PlayerSaveStore`).

### 3. Battery & Energy Profiling
1. Select the **Energy Log** template in Instruments.
2. Start a battle, then press the device lock button or push the app into the background.
3. Verify that the energy usage drops immediately to near-zero (confirming battle loop is paused).
