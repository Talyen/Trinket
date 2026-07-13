# TrinketCore-local guide

`TrinketCore` owns stable domain primitives: effects, stats, enums, and progression. Keep it independent of the app and feature UI; avoid importing higher-level packages.

Cover rules in the package test target. The root task-scoped workflow selects style and package checks; for a deliberately narrow iteration, run `./Scripts/test-package.sh TrinketCore`.
