# ContentView

## Responsibilities

- Renders the complete SwiftUI interface for the metronome.
- Reads published state from `MetronomeModel` through the environment object.
- Displays tempo, tempo name, beat dots, pendulum state, playback controls, sequence rows, grouping pickers, inline measure editors, start measure number, loop range controls, and loop count.
- Converts UI events into model calls: `togglePlayback()`, `tapTempo()`, `duplicateMeasure(at:)`, `updateMeasure(_:numerator:denominator:)`, `updateGrouping(for:grouping:)`, `updateLoopStartMeasureNumber(_:)`, `updateLoopEndMeasureNumber(_:)`, and `deleteMeasure(_:)`.
- Validates inline measure editor text before forwarding measure updates.
- Tracks local inline editing state for the selected measure, numerator text, denominator text, focus, and field validation errors.
- Lets the user change the first displayed measure number while keeping all rows consecutive.
- Lets the user enable a loop range and set inclusive `from` / `to` measure numbers.
- Lets the user insert a measure at any sequence boundary by copying the local context: before the first row copies the first measure, and other boundaries copy the previous measure.
- Lets the user tap a measure label to edit its numerator and denominator in that row.
- Lets the user choose curated grouping presets per measure from a row menu instead of tapping the small dots directly.
- Disables delete actions when the sequence has only one measure.
- Uses `FlowLayout` to wrap main beat dots and compact sequence dots, with visual markers for downbeats and configured subaccents.
- Highlights rows that are inside the enabled loop range and marks the loop start/end rows.

## Future Change Notes

- Keep this view focused on presentation, local input state, and forwarding user intent.
- Move shared business rules into `MetronomeModel` when they affect playback, persistence, or sequence state.
- Update `USER_ACTION_SEQUENCE.md` when adding or removing user actions from this view.
