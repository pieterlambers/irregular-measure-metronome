# UserDefaults

## Responsibilities

- Stores the encoded composition under `metro.composition.v2`, including `startMeasureNumber` and the measure sequence.
- Provides saved composition data during `MetronomeModel` initialization.
- Allows `MetronomeModel` to migrate legacy encoded measure sequences from `metro.sequence.v1`.
- Allows `MetronomeModel` to remove invalid persisted data when encoding fails.
- Does not own validation rules; `MetronomeModel` validates decoded sequence values.

## Future Change Notes

- Update this file if the storage key, stored payload, migration strategy, or persistence backend changes.
- Update `ARCHITECTURE.md` if persistence moves away from `UserDefaults`.
- Keep persistence behavior reflected in `USER_ACTION_SEQUENCE.md` for insert and delete measure flows.
