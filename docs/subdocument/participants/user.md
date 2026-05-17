# User

## Responsibilities

- Initiates all user-facing actions through the SwiftUI interface.
- Starts and pauses playback with the play/pause control.
- Changes tempo directly with the BPM slider.
- Sets tempo by tapping the TEMPO button repeatedly.
- Enters numerator and denominator values for new measures.
- Inserts valid measures at sequence boundaries, including before the first measure.
- Chooses optional grouping presets for a measure, such as `2+2+3` in `7/8`.
- Deletes existing measures when more than one measure remains.

## Future Change Notes

- Update this file when new controls, gestures, keyboard shortcuts, or external inputs are added.
- Keep the user action names aligned with `USER_ACTION_SEQUENCE.md`.
