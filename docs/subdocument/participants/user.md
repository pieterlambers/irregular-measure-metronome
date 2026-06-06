# User

## Responsibilities

- Initiates all user-facing actions through the SwiftUI interface.
- Selects, creates, duplicates, locks, unlocks, renames, resets, and deletes songs from the song library controls.
- Starts and pauses playback with the play/pause control.
- Enables or disables the 4/4 count-in before playback.
- Changes tempo directly with the BPM slider.
- Sets tempo by tapping the TEMPO button repeatedly.
- Types or steps the first displayed measure number.
- Inserts measures at sequence boundaries by copying the nearby measure.
- Edits a measure by stepping compact numerator and denominator controls in the inserted or existing measure row.
- Chooses optional grouping presets for a measure, such as `2+2+3` in `7/8`.
- Deletes existing measures when more than one measure remains.
- Can play read-only songs and adjust count-in or loop settings, but cannot edit their tempo, measure numbering, or sequence until unlocking them or duplicating an editable copy.

## Future Change Notes

- Update this file when new controls, gestures, keyboard shortcuts, or external inputs are added.
- Keep the user action names aligned with `USER_ACTION_SEQUENCE.md`.
