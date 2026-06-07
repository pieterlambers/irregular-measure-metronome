# Audio Scheduling

This document describes the buffered audio scheduling behavior in the latest committed code, introduced by commit `2df7a19` (`Buffer metronome audio scheduling`).

## Ownership

- `MetronomeModel` owns the user-visible playback lifecycle and published state.
- `ClickEngine` owns timing-critical audio scheduling once playback starts.
- `Task.sleep` is still used by `MetronomeModel` for short UI delays: BPM flash timing and tap-tempo reset timing.

## Playback Start

1. `MetronomeModel.start()` starts at the active loop start, or measure `0` when loop range is disabled.
2. `MetronomeModel.start(atMeasureIndex:)` starts at the tapped measure when the index is valid.
   - With loop range disabled, the tapped measure starts playback across the whole sequence.
   - With loop range enabled and the tapped measure inside the range, the tapped measure starts playback and the configured range remains active.
   - With loop range enabled and the tapped measure before the range, playback starts at the tapped measure, continues through the loop range end, then wraps to the loop start.
   - With loop range enabled and the tapped measure after the range, the model disables loop range and starts playback at the tapped measure across the whole sequence.
3. The chosen start method resets `currentBeat`, `currentMeasureIndex`, `loopCount`, and `isCountingIn`.
4. `MetronomeModel.startPlayback(measureIndex:beat:loopCount:)` increments `playbackGeneration`.
5. `MetronomeModel` calls `ClickEngine.start(...)` with the current BPM, sequence, starting position, loop count, optional four-beat 4/4 count-in, and an `onBeat` callback.
6. `ClickEngine.start(...)` prepares playback by lazily creating the audio engine and player node when needed, activating the audio session, starting the engine, cancelling any previous scheduler, creating a new scheduling generation, normalizing the starting playback state, stopping the player node, filling the initial audio queue, and then starting the player node.

When the 4/4 count-in is enabled, `ClickEngine` schedules four quarter-note count-in beats at the current BPM before the first real beat. The count-in is anchored to the selected playback start measure, so tapping a measure counts into that measure.

## Buffered Queue

- `ClickEngine` schedules ahead on a private serial `DispatchQueue` named `metro.click-engine.scheduler`.
- It keeps up to `maxQueuedBeats` buffered beats, currently `12`.
- `AVAudioEngine` and `AVAudioPlayerNode` are not created at app launch; they are initialized during playback preparation.
- Initial playback queues the first buffered beats before calling `AVAudioPlayerNode.play()`, so the player does not start on an empty queue.
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
- triggers the short BPM flash.

## Restart and Stop Behavior

- Changing `bpm` while playback is running stops playback so the next Play action starts with a freshly buffered queue at the new tempo.
- `ClickEngine` generation checks prevent stale scheduler work and stale callbacks from updating the model after a stop or restart.
- Audio session interruptions stop playback through `MetronomeModel.stop()` so calls, Siri, and similar system events leave the metronome stopped until the user presses Play again.
- Route changes reactivate the audio session and engine, then resume the player only when buffered playback is still active.
- `MetronomeModel.stop()` increments `playbackGeneration`, tells `ClickEngine` to stop, cancels flash state, resets `currentBeat` to `-1`, and clears count-in state.
- Inserting or deleting a measure persists the updated sequence and stops playback when it was running.

## Maintenance Notes

- Keep audio queue timing inside `ClickEngine` unless the scheduling architecture intentionally changes.
- Keep published playback state and stale-callback filtering in `MetronomeModel`.
- Update `ARCHITECTURE.md`, `USER_ACTION_SEQUENCE.md`, and the participant files when changing this scheduling flow.
- If `maxQueuedBeats`, the refill timer interval, click duration, click buffer roles, callback strategy, or silence-buffer caching changes, update this document in the same change.
