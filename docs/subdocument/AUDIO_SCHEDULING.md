# Audio Scheduling

This document describes the buffered audio scheduling behavior in the latest committed code, introduced by commit `2df7a19` (`Buffer metronome audio scheduling`).

## Ownership

- `MetronomeModel` owns the user-visible playback lifecycle and published state.
- `ClickEngine` owns timing-critical audio scheduling once playback starts.
- `Task.sleep` is still used by `MetronomeModel` for short UI delays: BPM flash timing and tap-tempo reset timing.

## Playback Start

1. `MetronomeModel.start()` resets `currentBeat`, `currentMeasureIndex`, `loopCount`, `isCountingIn`, and `pendulumDirection`.
2. `MetronomeModel.startPlayback(measureIndex:beat:loopCount:)` increments `playbackGeneration`.
3. `MetronomeModel` calls `ClickEngine.start(...)` with the current BPM, sequence, starting position, loop count, optional four-beat 4/4 count-in, and an `onBeat` callback.
4. `ClickEngine.start(...)` prepares the audio engine, cancels any previous scheduler, creates a new scheduling generation, normalizes the starting playback state, restarts the player node, and fills the initial audio queue.

When the 4/4 count-in is enabled, `ClickEngine` schedules four quarter-note count-in beats at the current BPM before the first real beat. The count-in is anchored to the active loop start, so playback begins at the loop start after beat 4 of the count-in.

## Buffered Queue

- `ClickEngine` schedules ahead on a private serial `DispatchQueue` named `metro.click-engine.scheduler`.
- It keeps up to `maxQueuedBeats` buffered beats, currently `12`.
- Each beat is scheduled as a click buffer followed by a silence buffer.
- The click buffer is accented when the scheduled beat is `0`, subaccented when the beat starts a configured measure grouping, and regular otherwise.
- Count-in beats use a 4/4 quarter-note interval regardless of the starting measure's time signature.
- In `x/8` measures, non-accented eighth-note positions are scheduled as silence so only the downbeat and configured grouping starts are heard.
- Silence buffer length is calculated from the current BPM and the current measure denominator:

```swift
(60 / Double(bpm)) * (4 / Double(denominator))
```

- Silence buffers are cached by frame count so repeated intervals can reuse the same `AVAudioPCMBuffer`.
- A `DispatchSourceTimer` wakes every `100 ms` on the scheduler queue to refill the queue as scheduled beats complete.

## UI Beat Callback

`ClickEngine` separately schedules the `onBeat` callback with `DispatchQueue.main.asyncAfter`.

This callback is used for UI state, not for audio playback. When it fires, `MetronomeModel.showScheduledBeat(...)`:

- ignores stale callbacks by checking `playbackGeneration`;
- ignores callbacks when playback is stopped;
- updates `currentMeasureIndex`, `currentBeat`, and `loopCount`;
- updates `isCountingIn` while count-in beats are being reflected in the UI;
- triggers the short BPM flash;
- flips `pendulumDirection`.

## Restart and Stop Behavior

- Changing `bpm` while playback is running calls `restartPlaybackFromCurrentPosition()`.
- The restart keeps the current measure, current beat, and loop count, increments the model playback generation, and starts a fresh `ClickEngine` scheduling generation.
- `ClickEngine` generation checks prevent stale scheduler work and stale callbacks from updating the model after a restart.
- `MetronomeModel.stop()` increments `playbackGeneration`, tells `ClickEngine` to stop, cancels flash state, resets `currentBeat` to `-1`, and resets `pendulumDirection` to `0`.
- Inserting or deleting a measure persists the updated sequence and stops playback when it was running.

## Maintenance Notes

- Keep audio queue timing inside `ClickEngine` unless the scheduling architecture intentionally changes.
- Keep published playback state and stale-callback filtering in `MetronomeModel`.
- Update `ARCHITECTURE.md`, `USER_ACTION_SEQUENCE.md`, and the participant files when changing this scheduling flow.
- If `maxQueuedBeats`, the refill timer interval, click duration, click buffer roles, callback strategy, or silence-buffer caching changes, update this document in the same change.
