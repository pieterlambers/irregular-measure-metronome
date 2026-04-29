# Irregular Measure Metronome Docs

Start here when changing the app. These notes describe the current shape of the code and the user-facing flows that should stay in sync with implementation changes.

## Documents

- [Architecture](subdocument/ARCHITECTURE.md): high-level component ownership and data flow.
- [User Action Sequence Diagram](subdocument/USER_ACTION_SEQUENCE.md): sequence-level behavior for every current user action.

## Codex Maintenance Notes

Use these docs as working context before adjusting the code:

- Check [Architecture](subdocument/ARCHITECTURE.md) before changing ownership between `ContentView`, `MetronomeModel`, `ClickEngine`, persistence, or timing.
- Check [User Action Sequence Diagram](subdocument/USER_ACTION_SEQUENCE.md) before changing play/pause, BPM changes, tap tempo, measure entry, add measure, or delete measure behavior.
- Update the diagrams in the same change when adding, removing, or rerouting a user action.
- Keep `MetronomeModel` as the source of truth for playback state, timing, sequence state, tap tempo, and persistence unless the architecture is intentionally changed.
- Keep `ClickEngine` focused on audio setup and click playback.
- Keep `ContentView` focused on rendering state and forwarding user actions to the model.

## Code Map

- `IrregularMeasureMetronome/IrregularMeasureMetronomeApp.swift`: creates and injects the shared `MetronomeModel`.
- `IrregularMeasureMetronome/ContentView.swift`: renders the SwiftUI interface and forwards user actions.
- `IrregularMeasureMetronome/MetronomeModel.swift`: owns app state, playback timing, tap tempo, sequence edits, and persistence.
- `IrregularMeasureMetronome/ClickEngine.swift`: prepares the audio engine and plays accented or regular clicks.
