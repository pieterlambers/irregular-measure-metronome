# Irregular Measure Metronome Docs

Start here when changing the app. These notes describe the current shape of the code and the user-facing flows that should stay in sync with implementation changes.

## Documents

- [Architecture](subdocument/ARCHITECTURE.md): high-level component ownership and data flow.
- [Audio Scheduling](subdocument/AUDIO_SCHEDULING.md): buffered click scheduling introduced by the latest committed audio changes.
- [User Action Sequence Diagram](subdocument/USER_ACTION_SEQUENCE.md): sequence-level behavior for every current user action.
- [Sequence Participants](subdocument/participants): responsibility notes for each participant in the user action sequence diagram.

## Codex Maintenance Notes

Use these docs as working context before adjusting the code:

- Check [Architecture](subdocument/ARCHITECTURE.md) before changing ownership between `ContentView`, `MetronomeModel`, `ClickEngine`, persistence, or timing.
- Check [Audio Scheduling](subdocument/AUDIO_SCHEDULING.md) before changing `ClickEngine` buffering, scheduler queue behavior, callback timing, or playback restarts.
- Check [User Action Sequence Diagram](subdocument/USER_ACTION_SEQUENCE.md) before changing play/pause, BPM changes, tap tempo, measure entry, insert measure, or delete measure behavior.
- Check [Sequence Participants](subdocument/participants) before changing a participant's responsibilities.
- Update the diagrams in the same change when adding, removing, or rerouting a user action.
- Keep `MetronomeModel` as the source of truth for published playback state, sequence state, tap tempo, and persistence unless the architecture is intentionally changed.
- Keep `ClickEngine` focused on audio setup, buffered click scheduling, and audio-to-UI beat callbacks.
- Keep `ContentView` focused on rendering state and forwarding user actions to the model.

## Code Map

- `IrregularMeasureMetronome/IrregularMeasureMetronomeApp.swift`: creates and injects the shared `MetronomeModel`.
- `IrregularMeasureMetronome/ContentView.swift`: renders the SwiftUI interface and forwards user actions.
- `IrregularMeasureMetronome/MetronomeModel.swift`: owns app state, playback lifecycle, tap tempo, sequence edits, and persistence.
- `IrregularMeasureMetronome/ClickEngine.swift`: prepares the audio engine and schedules buffered accented or regular clicks.
