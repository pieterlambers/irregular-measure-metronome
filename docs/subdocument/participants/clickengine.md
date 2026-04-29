# ClickEngine

## Responsibilities

- Owns audio engine setup for metronome clicks.
- Prepares `AVAudioEngine`, `AVAudioPlayerNode`, and click buffers.
- Configures playback audio session behavior.
- Generates separate accented and regular click buffers.
- Plays the requested click buffer when `MetronomeModel` calls `playClick(accented:)`.
- Keeps audio generation and playback isolated from UI and sequence logic.

## Future Change Notes

- Keep this component focused on audio output.
- Avoid adding UI state, sequence state, or timing-loop ownership here.
- Update `ARCHITECTURE.md` if audio responsibilities are split across multiple components.
