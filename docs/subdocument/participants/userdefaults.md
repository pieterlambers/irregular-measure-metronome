# UserDefaults

## Responsibilities

- Stores the encoded local song library under `metro.songLibrary.v1`, including the current song ID and each song's name, BPM, `startMeasureNumber`, measure sequence, optional per-measure grouping arrays, optional loop range settings, 4/4 count-in setting, and update timestamp.
- Provides saved song library data during `MetronomeModel` initialization.
- Allows `MetronomeModel` to migrate the previous single-composition payload from `metro.composition.v2`.
- Allows `MetronomeModel` to migrate legacy encoded measure sequences from `metro.sequence.v1`.
- Allows `MetronomeModel` to remove invalid persisted data when encoding fails.
- Does not own validation rules; `MetronomeModel` validates decoded song and sequence values and derives built-in song editing locks from hardcoded built-in song IDs.

## Future Change Notes

- Update this file if the storage key, stored payload, migration strategy, or persistence backend changes.
- Update `ARCHITECTURE.md` if persistence moves away from `UserDefaults`.
- Keep persistence behavior reflected in `USER_ACTION_SEQUENCE.md` for song-library, insert, and delete measure flows.
