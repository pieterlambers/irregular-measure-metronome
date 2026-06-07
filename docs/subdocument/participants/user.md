# User

## Responsibilities

- Initiates all user-facing actions through the SwiftUI interface.
- Selects, creates, duplicates, renames, resets, and deletes songs from the song library controls.
- Starts and pauses playback with the play/pause control.
- Enables or disables the 4/4 count-in before playback.
- Changes tempo directly with the BPM slider.
- Sets tempo by tapping the TEMPO button repeatedly.
- Types or steps the first displayed measure number.
- Inserts measures at sequence boundaries by copying the nearby measure.
- Edits a measure by dragging compact numerator and denominator wheel controls in the inserted or existing measure row.
- Temporarily unlocks editing for a built-in song by long-pressing a locked composition-edit control, then edits before 3 idle seconds pass.
- Chooses optional grouping presets for a measure, such as `2+2+3` in `7/8`.
- Deletes existing measures when more than one measure remains.
- Can play editing-locked built-in songs and adjust tempo, count-in, or loop settings, but cannot edit their measure numbering or sequence until temporarily unlocking from a locked edit control or duplicating an editable copy.

## Future Change Notes

- Update this file when new controls, gestures, keyboard shortcuts, or external inputs are added.
- Keep the user action names aligned with `USER_ACTION_SEQUENCE.md`.
