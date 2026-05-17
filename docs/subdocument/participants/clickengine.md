# ClickEngine

## Responsibilities

- Owns audio engine setup for metronome clicks.
- Prepares `AVAudioEngine`, `AVAudioPlayerNode`, and click buffers.
- Configures playback audio session behavior.
- Generates separate accented, subaccented, and regular click buffers.
- Starts buffered playback for a BPM, measure sequence, starting beat, starting measure, and loop count.
- Schedules each beat as a click buffer followed by a calculated silence buffer, using subaccent clicks for configured grouping starts.
- Calculates beat intervals from BPM and each measure denominator.
- Maintains a private serial scheduler queue and `DispatchSourceTimer` to keep the audio queue filled.
- Caps the buffered queue at `maxQueuedBeats`, currently `12`.
- Caches silence buffers by frame count.
- Tracks scheduler generations so stale work is ignored after restart or stop.
- Calls `MetronomeModel` through the supplied `onBeat` callback when a scheduled beat should be reflected in the UI.
- Keeps audio generation and buffered playback isolated from SwiftUI presentation and persistence logic.

## Future Change Notes

- Keep this component focused on audio output.
- Avoid adding UI state, sequence state, or timing-loop ownership here.
- Keep user-visible state publication in `MetronomeModel`; callbacks from this engine should report scheduled beats, not mutate UI directly.
- Update `../AUDIO_SCHEDULING.md` when changing queue depth, timer cadence, callback timing, or buffer construction.
- Update `ARCHITECTURE.md` if audio responsibilities are split across multiple components.
