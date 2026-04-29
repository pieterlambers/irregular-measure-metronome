# UserDefaults

## Responsibilities

- Stores the encoded measure sequence under `metro.sequence.v1`.
- Provides saved sequence data during `MetronomeModel` initialization.
- Allows `MetronomeModel` to remove invalid persisted data when encoding fails.
- Does not own validation rules; `MetronomeModel` validates decoded sequence values.

## Future Change Notes

- Update this file if the storage key, stored payload, migration strategy, or persistence backend changes.
- Update `ARCHITECTURE.md` if persistence moves away from `UserDefaults`.
- Keep persistence behavior reflected in `USER_ACTION_SEQUENCE.md` for add and delete measure flows.
