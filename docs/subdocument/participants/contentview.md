# ContentView

## Responsibilities

- Renders the complete SwiftUI interface for the metronome.
- Reads published state from `MetronomeModel` through the environment object.
- Switches between the compact single-column layout and the regular-width iPad layout based on `horizontalSizeClass`.
- On regular-width screens, keeps song, tempo, beat visualization, and transport controls in a left column while rendering the sequence editor as a two-column measure grid in the wider right column.
- Displays song selection and naming controls, tempo, tempo name, beat dots, pendulum state, playback controls, count-in control, sequence rows, grouping pickers, inline measure editors, start measure number, loop range controls, and loop count.
- Converts UI events into model calls and bindings: `selectSong(_:)`, `createSong()`, `duplicateCurrentSong()`, `resetCurrentSongToBuiltIn()`, `deleteCurrentSong()`, `togglePlayback()`, `isCountInFourFourEnabled`, `tapTempo()`, `duplicateMeasure(at:)`, `updateMeasure(_:numerator:denominator:)`, `updateGrouping(for:grouping:)`, `updateLoopStartMeasureNumber(_:)`, `updateLoopEndMeasureNumber(_:)`, and `deleteMeasure(_:)`.
- Validates inline measure editor text before forwarding measure updates.
- Tracks local editing state for the selected measure signature text, first measure number text, keyboard focus, and validation errors.
- Lets the user edit the current song name, switch songs from a menu, create a default song, duplicate the current song, reset editable built-in songs to their hardcoded version, and delete the current song when at least one other song exists.
- Lets the user enable a four-beat 4/4 count-in before playback starts from the active loop start.
- Lets the user type or step the first displayed measure number while keeping all rows consecutive.
- Lets the user enable a loop range and set inclusive `from` / `to` measure numbers.
- Lets the user insert a measure at any sequence boundary by copying the local context: before the first row copies the first measure, and other boundaries copy the previous measure.
- Lets the user tap a measure label to edit a full time signature string such as `7/8` in that row.
- Provides a keyboard `Done` action for numeric editors and commits valid measure signature edits from the row checkmark, keyboard `Done`, or focus changes.
- Lets the user choose curated grouping presets per measure from a row menu instead of tapping the small dots directly.
- Disables delete actions when the sequence has only one measure.
- Uses `FlowLayout` to wrap main beat dots and compact sequence dots, with visual markers for downbeats and configured subaccents.
- Highlights rows that are inside the enabled loop range and marks the loop start/end rows.

## Future Change Notes

- Keep this view focused on presentation, local input state, and forwarding user intent.
- Keep compact and regular-width layouts behaviorally equivalent when changing controls.
- Move shared business rules into `MetronomeModel` when they affect playback, persistence, or sequence state.
- Update `USER_ACTION_SEQUENCE.md` when adding or removing user actions from this view.
