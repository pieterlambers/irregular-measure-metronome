# MetronomeModel

## Responsibilities

- Acts as the source of truth for metronome state.
- Publishes UI state including `bpm`, `isPlaying`, `currentBeat`, `currentMeasureIndex`, `loopCount`, `sequence`, `tapTempoText`, `flashBPM`, and `pendulumDirection`.
- Starts playback by preparing audio, resetting playback counters, and beginning the tick loop.
- Stops playback by cancelling scheduled tasks and resetting transient playback indicators.
- Calculates beat intervals from BPM and the current measure denominator.
- Advances beats, measures, and loop count during playback.
- Triggers accented clicks on the first beat and regular clicks for other beats.
- Manages tap tempo timing, averaging, BPM clamping, and tap reset behavior.
- Adds and deletes measures while keeping sequence state valid.
- Saves and loads the measure sequence through `UserDefaults`.
- Sanitizes persisted sequence data and falls back to the default sequence when needed.

## Future Change Notes

- Keep playback timing, sequence mutation, tap tempo, and persistence rules here unless the architecture is intentionally changed.
- Update `ARCHITECTURE.md` if ownership moves out of this model.
- Update `USER_ACTION_SEQUENCE.md` when model behavior changes the order or result of a user action.
