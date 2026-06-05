# Brass Pulse Docs

Start here when changing the app. These notes describe the current shape of the code and the user-facing flows that should stay in sync with implementation changes.

## Documents

- [Architecture](subdocument/ARCHITECTURE.md): high-level component ownership and data flow.
- [Audio Scheduling](subdocument/AUDIO_SCHEDULING.md): buffered click scheduling introduced by the latest committed audio changes.
- [Manual QA](subdocument/MANUAL_QA.md): real-device iPhone and iPad checks for audio, lifecycle, layout, and App Store readiness.
- [Testing](subdocument/TESTING.md): what the XCTest target covers, the test seams it uses, and how to run it.
- [User Action Sequence Diagram](subdocument/USER_ACTION_SEQUENCE.md): sequence-level behavior for every current user action.
- [Sequence Participants](subdocument/participants): responsibility notes for each participant in the user action sequence diagram.

## Codex Maintenance Notes

Use these docs as working context before adjusting the code:

- Check [Architecture](subdocument/ARCHITECTURE.md) before changing ownership between `ContentView`, `MetronomeModel`, `ClickEngine`, persistence, or timing.
- Check [Audio Scheduling](subdocument/AUDIO_SCHEDULING.md) before changing `ClickEngine` buffering, scheduler queue behavior, callback timing, or playback restarts.
- Check [Manual QA](subdocument/MANUAL_QA.md) before TestFlight or App Store submission.
- Check [Testing](subdocument/TESTING.md) before changing `MetronomeModel`, `ClickEngine`, persistence, song read-only rules, tap tempo, or playback cursor behavior covered by unit tests.
- Check [User Action Sequence Diagram](subdocument/USER_ACTION_SEQUENCE.md) before changing play/pause, song locking, BPM changes, tap tempo, measure entry, grouping selection, insert measure, or delete measure behavior.
- Check [Sequence Participants](subdocument/participants) before changing a participant's responsibilities.
- Update the diagrams in the same change when adding, removing, or rerouting a user action.
- Keep `MetronomeModel` as the source of truth for published playback state, sequence state, tap tempo, and persistence unless the architecture is intentionally changed.
- Keep `ClickEngine` focused on audio setup, buffered click scheduling, and audio-to-UI beat callbacks.
- Keep `ContentView` focused on rendering state and forwarding user actions to the model.

## Code Map

- `IrregularMeasureMetronome/IrregularMeasureMetronomeApp.swift`: creates and injects the shared `MetronomeModel`.
- `IrregularMeasureMetronome/ContentView.swift`: renders the adaptive SwiftUI interface for compact iPhone widths and regular-width iPad layouts with a scrollable sequence area and active played-measure highlighting, then forwards user actions.
- `IrregularMeasureMetronome/MetronomeModel.swift`: owns app state, playback lifecycle, played-measure highlight derivation, tap tempo, song read-only rules, sequence edits, and persistence.
- `IrregularMeasureMetronome/ClickEngine.swift`: lazily prepares the audio engine and schedules buffered accented, subaccented, or regular clicks.
- `IrregularMeasureMetronomeTests/MetronomeCoreTests.swift`: unit-tests pure meter rules, playback cursor advancement, model sequence editing, loop ranges, playback callbacks including played-measure highlight state, tap tempo, read-only song behavior, and persistence migration.
