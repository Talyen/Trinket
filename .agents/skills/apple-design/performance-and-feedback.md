# Performance and feedback

Keep visual, sound, and haptic feedback tied to the same committed event. Use the
existing audio and feedback owners; independent timers can drift or fire twice.
Reserve feedback for a meaningful press, commit, success, or failure.

For responsiveness problems, identify the delayed action before changing motion.
Check unnecessary view invalidation, unstable identity, and work on the input
path. A new blur or stretch effect is not a remedy for missed frames.

Use [the performance playbook](../../../Docs/Platform/PerformanceInvestigationPlaybook.md)
when the request needs measurement. Preserve artwork working-set policy during
optimization. Simulator observations can locate a problem, but device timing and
physical haptic quality require device evidence.

Review whether feedback fires once, agrees with the resulting state, and remains
coherent when the action is cancelled, repeated, or fails.
