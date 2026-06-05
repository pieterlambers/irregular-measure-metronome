# ContentView

## Responsibilities

- Renders the complete SwiftUI interface for the metronome.
- Reads published state from `MetronomeModel` through the environment object.
- Switches between stacked and split layouts based on available width, and chooses one or two sequence columns from the measured sequence width.
- In the stacked layout, keeps song, compact tempo, beat visualization, playback controls, and loop status visible above a dedicated scrollable sequence pane, with an optional measure-focused mode that gives most of the screen to measure rows.
- In the split layout, keeps song, tempo, beat visualization, and transport controls in a left column while rendering the sequence editor as a dedicated scrollable one- or two-column measure grid on the right side.
- Displays song selection, naming, and lock controls, tempo, tempo name, beat dots, playback controls, count-in control, sequence rows, active playback measure highlighting, compact drag-adjustable time signature controls, grouping pickers, start measure number, loop range controls, and loop count.
- Converts UI events into model calls and bindings: `selectSong(_:)`, `createSong()`, `duplicateCurrentSong()`, `setCurrentSongReadOnly(_:)`, `resetCurrentSongToBuiltIn()`, `deleteCurrentSong()`, `togglePlayback()`, `isCountInFourFourEnabled`, `tapTempo()`, `duplicateMeasure(at:)`, `updateMeasure(_:numerator:denominator:)`, `updateGrouping(for:grouping:)`, `updateLoopStartMeasureNumber(_:)`, `updateLoopEndMeasureNumber(_:)`, and `deleteMeasure(_:)`.
- Limits compact time signature control choices to common musical numerator and denominator values before forwarding measure updates.
- Tracks local editing state for first measure number text, inline song picker expansion, inline grouping picker expansion, and keyboard focus.
- Lets the user edit the current song name, lock or unlock the current song, switch songs from an inline expandable song picker, create a default song, duplicate the current song, reset built-in songs to their hardcoded read-only version, and delete the current song when at least one other song exists.
- Shows a lock indicator for read-only songs and disables editing controls for locked songs while keeping playback controls usable.
- Lets the user enable a four-beat 4/4 count-in before playback starts from the active loop start.
- Lets the user type or step the first displayed measure number while keeping all rows consecutive.
- Lets the user enable a loop range and set inclusive `from` / `to` measure numbers.
- Lets the user insert a measure at any sequence boundary by copying the local context: before the first row copies the first measure, and other boundaries copy the previous measure.
- Lets the user adjust numerator and denominator directly in every measure row by dragging vertically on compact number controls, with an active readout that keeps the selected value visible during the drag.
- Provides a keyboard `Done` action for text-field numeric editors such as the first displayed measure number.
- Lets the user choose meaningful multi-part grouping presets per measure from an inline row picker instead of tapping the small dots directly, omitting single-group choices that behave the same as `None`.
- Disables delete actions when the sequence has only one measure.
- Keeps the main beat dots on one responsive row while using `FlowLayout` to wrap compact sequence dots, with visual markers for downbeats and configured subaccents.
- Highlights rows that are inside the enabled loop range and marks the loop start/end rows.
- Highlights the measure currently being played with a stronger card treatment, using `MetronomeModel.isPlayedMeasure(index:)` so count-in beats do not mark a sequence measure as active.
- Auto-scrolls the sequence list/grid during playback so the highlighted played measure remains visible.

## Future Change Notes

- Keep this view focused on presentation, local input state, and forwarding user intent.
- Keep compact and regular-width layouts behaviorally equivalent when changing controls.
- Keep the inline song and grouping pickers in SwiftUI-owned layout unless there is an intentional reason to return to UIKit-backed menu or dialog presentation.
- Move shared business rules into `MetronomeModel` when they affect playback, persistence, or sequence state.
- Update `USER_ACTION_SEQUENCE.md` when adding or removing user actions from this view.
