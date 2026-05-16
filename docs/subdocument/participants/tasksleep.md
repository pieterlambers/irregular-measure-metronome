# Task.sleep

## Responsibilities

- Represents asynchronous UI delays used by `MetronomeModel`.
- Handles short flash timing for the BPM highlight, currently `80 ms`.
- Handles tap-tempo reset timing after a period without taps, currently `2500 ms`.
- Supports cancellation through stored `Task` references in `MetronomeModel`.
- Does not schedule the metronome beat loop in the current architecture; buffered beat scheduling lives in `ClickEngine`.

## Future Change Notes

- Update this file if timing moves to a different scheduler, clock, audio callback, or timer mechanism.
- Keep cancellation behavior documented when adding new delayed actions.
- Update `../AUDIO_SCHEDULING.md` if `Task.sleep` becomes part of beat scheduling again.
- Update `USER_ACTION_SEQUENCE.md` when timing changes alter user-visible behavior.
