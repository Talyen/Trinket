# Performance and feedback

Keep visual, sound, and haptic feedback tied to the same committed event. Use the
existing audio and feedback owners; independent timers can drift or fire twice.
Reserve feedback for a meaningful press, commit, success, or failure.

Keep system haptic meanings consistent: selection for a changed choice, impact for
a physical event, and notification feedback for an outcome. Avoid duplicating a
native control's existing haptic. Match feedback intensity to the event, avoid
fatiguing repetition, and keep the result understandable with sound or haptics off.

For responsiveness problems, identify the delayed action before changing motion.
Check unnecessary view invalidation, unstable identity, and work on the input
path. A new blur or stretch effect is not a remedy for missed frames.

Use [the performance playbook](../../../Docs/Platform/PerformanceInvestigationPlaybook.md)
when the request needs measurement. Preserve artwork working-set policy during
optimization. Simulator observations can locate a problem, but device timing and
physical haptic quality require device evidence.

Review whether feedback fires once, agrees with the resulting state, and remains
coherent when the action is cancelled, repeated, or fails.

When changing playback/session behavior, follow the [audio owner](../../../Docs/AgentContext/audio.md)
and check silent mode, another app's audio, an interruption and return, and headphone
connection/disconnection on a device. Preserve Trinket's ambient/mixing policy and
Options settings; don't adjust system volume. Trace existing session and lifecycle
handling before adding notification observers. A missing local handler is only an
investigation lead, and Simulator evidence does not establish physical output.

Apple references: [Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio)
and [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics).
