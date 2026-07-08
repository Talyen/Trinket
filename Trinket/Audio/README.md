# Audio

Looping menu and encounter music via `MusicPlayer`.

## Stack choice

`AVAudioPlayer` + `AVAudioSession` category `.ambient` with `.mixWithOthers` is intentional:

- Ambient audio ducks under other apps and respects the Silent switch.
- Simple looping BGM does not need `AVAudioEngine` graph complexity.
- Crossfades use structured `Task` cancellation on the main actor.

Do not migrate to AudioEngine unless product needs spatial audio, real-time effects, or sample-accurate scheduling.
