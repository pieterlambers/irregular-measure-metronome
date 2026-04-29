# Task.sleep

## Responsibilities

- Represents asynchronous delays used by `MetronomeModel`.
- Schedules the next playback tick based on the current BPM and measure denominator.
- Handles short flash timing for the BPM highlight.
- Handles tap-tempo reset timing after a period without taps.
- Supports cancellation through stored `Task` references in `MetronomeModel`.

## Future Change Notes

- Update this file if timing moves to a different scheduler, clock, audio callback, or timer mechanism.
- Keep cancellation behavior documented when adding new delayed actions.
- Update `USER_ACTION_SEQUENCE.md` when timing changes alter user-visible behavior.
