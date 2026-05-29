# MetronomeModel

## Responsibilities

- Acts as the source of truth for metronome state.
- Publishes UI state including `songs`, `currentSongID`, `currentSongName`, `bpm`, `isPlaying`, `currentBeat`, `currentMeasureIndex`, `loopCount`, `isCountingIn`, `isCountInFourFourEnabled`, `sequence`, `startMeasureNumber`, `isLoopRangeEnabled`, loop boundary indices, `tapTempoText`, `flashBPM`, and `pendulumDirection`.
- Manages the local song library, including selecting songs, creating default songs, duplicating the current song, resetting editable built-in songs to their hardcoded version, deleting the current song when another song exists, and renaming the current song.
- Starts playback by resetting published playback counters and asking `ClickEngine` to start buffered scheduling, with a four-beat 4/4 count-in when enabled.
- Stops playback by incrementing `playbackGeneration`, stopping `ClickEngine`, cancelling flash timing, and resetting transient playback indicators.
- Receives scheduled beat callbacks from `ClickEngine`.
- Filters stale beat callbacks with `playbackGeneration`.
- Publishes the current beat, measure, loop count, count-in state, flash state, and pendulum direction in response to current beat callbacks.
- Restarts buffered playback from the current position when BPM changes during playback.
- Persists BPM and the 4/4 count-in setting as part of the current song.
- Manages tap tempo timing, averaging, BPM clamping, and tap reset behavior.
- Derives displayed measure numbers from `startMeasureNumber + sequence index`.
- Maps displayed loop range measure numbers to sequence indices and passes the active inclusive range to `ClickEngine`.
- Inserts measures at selected sequence indices, duplicates measures from local sequence context, updates measure signatures and groupings, and deletes measures while keeping sequence state valid and measure numbers consecutive.
- Saves and loads the local song library through `UserDefaults`.
- Migrates the previous single-composition format and legacy persisted measure sequences into the current song-library format.
- Sanitizes persisted song data, including names, BPM, measure numbers, sequences, and optional grouping arrays, and falls back to a default song when needed.

## Future Change Notes

- Keep playback lifecycle, published state, song-library operations, sequence mutation, tap tempo, and persistence rules here unless the architecture is intentionally changed.
- Keep timing-critical audio queue scheduling in `ClickEngine`.
- Update `ARCHITECTURE.md` if ownership moves out of this model.
- Update `USER_ACTION_SEQUENCE.md` when model behavior changes the order or result of a user action.
