# MetronomeModel

## Responsibilities

- Acts as the source of truth for metronome state.
- Publishes UI state including `bpm`, `isPlaying`, `currentBeat`, `currentMeasureIndex`, `loopCount`, `sequence`, `startMeasureNumber`, `isLoopRangeEnabled`, loop boundary indices, `tapTempoText`, `flashBPM`, and `pendulumDirection`.
- Starts playback by resetting published playback counters and asking `ClickEngine` to start buffered scheduling.
- Stops playback by incrementing `playbackGeneration`, stopping `ClickEngine`, cancelling flash timing, and resetting transient playback indicators.
- Receives scheduled beat callbacks from `ClickEngine`.
- Filters stale beat callbacks with `playbackGeneration`.
- Publishes the current beat, measure, loop count, flash state, and pendulum direction in response to current beat callbacks.
- Restarts buffered playback from the current position when BPM changes during playback.
- Manages tap tempo timing, averaging, BPM clamping, and tap reset behavior.
- Derives displayed measure numbers from `startMeasureNumber + sequence index`.
- Maps displayed loop range measure numbers to sequence indices and passes the active inclusive range to `ClickEngine`.
- Inserts measures at selected sequence indices, duplicates measures from local sequence context, updates measure signatures and groupings, and deletes measures while keeping sequence state valid and measure numbers consecutive.
- Saves and loads the composition through `UserDefaults`.
- Migrates legacy persisted measure sequences into the current composition format.
- Sanitizes persisted composition data, including optional grouping arrays, and falls back to the default sequence when needed.

## Future Change Notes

- Keep playback lifecycle, published state, sequence mutation, tap tempo, and persistence rules here unless the architecture is intentionally changed.
- Keep timing-critical audio queue scheduling in `ClickEngine`.
- Update `ARCHITECTURE.md` if ownership moves out of this model.
- Update `USER_ACTION_SEQUENCE.md` when model behavior changes the order or result of a user action.
