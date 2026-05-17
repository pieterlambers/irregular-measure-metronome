# ContentView

## Responsibilities

- Renders the complete SwiftUI interface for the metronome.
- Reads published state from `MetronomeModel` through the environment object.
- Displays tempo, tempo name, beat dots, pendulum state, playback controls, sequence rows, grouping pickers, start measure number, measure inputs, and loop count.
- Converts UI events into model calls: `togglePlayback()`, `tapTempo()`, `insertMeasure(at:numerator:denominator:)`, `updateGrouping(for:grouping:)`, and `deleteMeasure(_:)`.
- Validates measure text fields before forwarding insert-measure requests.
- Tracks local input state for numerator text, denominator text, and field validation errors.
- Lets the user change the first displayed measure number while keeping all rows consecutive.
- Lets the user insert a measure at any sequence boundary, including before the first row, using the current measure input fields.
- Lets the user choose curated grouping presets per measure from a row menu instead of tapping the small dots directly.
- Disables delete actions when the sequence has only one measure.
- Uses `FlowLayout` to wrap main beat dots and compact sequence dots, with visual markers for downbeats and configured subaccents.

## Future Change Notes

- Keep this view focused on presentation, local input state, and forwarding user intent.
- Move shared business rules into `MetronomeModel` when they affect playback, persistence, or sequence state.
- Update `USER_ACTION_SEQUENCE.md` when adding or removing user actions from this view.
