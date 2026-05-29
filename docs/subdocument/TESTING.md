# Testing

## Test Target

`IrregularMeasureMetronomeTests` is the app's XCTest bundle. It imports the app with `@testable import IrregularMeasureMetronome` and focuses on deterministic unit tests, not real audio output or SwiftUI rendering.

The tests live in:

- `IrregularMeasureMetronomeTests/MetronomeCoreTests.swift`

## What Is Tested

### Time Signatures

`TimeSignatureTests` covers the pure music-structure rules:

- `label` renders as `numerator/denominator`.
- `groupingLabel` renders valid groupings as `2+2+3`, otherwise `None`.
- `validGrouping` accepts only multi-part, positive groupings that sum to the numerator.
- `isSubaccented(beat:)` returns true only for internal group starts, such as beats `2` and `4` in `7/8 [2, 2, 3]`.

### Playback Cursor

`PlaybackCursorTests` covers the pure beat-advance state machine extracted from `ClickEngine`:

- start measure normalization into the active loop range;
- oversized start beat normalization back to `0`;
- beat advancement inside a measure;
- movement from the end of one measure to the next;
- loop wrap from loop end back to loop start;
- loop count incrementing after wrap;
- count-in beat advancement before the real sequence begins;
- defensive clamping for negative loop counts and count-in values.

### Sequence Editing

`MetronomeModelSequenceTests` covers user-facing sequence mutation rules:

- inserting valid measures at clamped indices;
- rejecting invalid numerator and denominator values;
- duplicating from the previous measure template;
- preserving cleaned grouping when duplicating;
- refusing to delete the final remaining measure;
- clearing grouping when a measure update makes it invalid;
- stopping playback when the sequence changes.

### Loop Ranges

`MetronomeModelLoopRangeTests` covers measure-number and loop-boundary behavior:

- displayed measure numbers derive from `startMeasureNumber + index`;
- loop boundary setters map displayed measure numbers back to sequence indices;
- loop boundaries clamp to sequence bounds;
- loop start and end do not cross;
- disabled loop playback uses the full sequence;
- enabled loop playback passes only the active loop range to the click engine;
- sequence shrink normalizes loop range and current playback position safely.

### Playback Model State

`MetronomeModelPlaybackTests` covers the model-to-engine contract and callback handling:

- `start()` resets playback state and calls the click engine with expected BPM, sequence, beat, loop range, loop count, and count-in settings;
- `stop()` clears transient playback state and stops the click engine;
- BPM changes while playing restart playback from the current position;
- count-in enabled playback starts with four count-in beats;
- fake beat callbacks update visible playback state, flash state, and pendulum direction;
- stale beat callbacks from previous playback generations are ignored.

### Tap Tempo

`TapTempoTests` covers deterministic tap tempo behavior through an injected clock:

- first tap leaves the display as `TAP`;
- repeated taps average intervals into BPM;
- computed BPM clamps to `20...300`;
- tap text updates to the computed BPM;
- reset timing returns tap text to `TAP`.

### Song Library Persistence

`SongLibraryPersistenceTests` covers persistence using isolated `UserDefaults` suites:

- loading a persisted song library and selecting the saved current song;
- falling back when the saved current song ID is missing;
- sanitizing names, BPM, start measure number, sequences, and grouping;
- falling back to the default song when stored songs are invalid;
- migrating `metro.composition.v2`;
- migrating `metro.sequence.v1`;
- including the built-in song exactly once;
- preserving edits to persisted built-in songs and resetting them to their hardcoded version on request.

## Test Seams

The tests rely on small production seams that keep behavior deterministic:

- `ClickEngineProtocol` lets `MetronomeModel` use a fake click engine in tests.
- `PlaybackCursor` keeps beat advancement testable without touching `AVAudioEngine`.
- `MetronomeModel` accepts an injected `UserDefaults` instance so tests do not touch `UserDefaults.standard`.
- `MetronomeModel` accepts an injected clock and tap-reset delay so tap tempo tests do not depend on wall-clock timing.

## What Is Not Unit Tested

These are intentionally left out of unit tests:

- actual audio output;
- `AVAudioSession` setup;
- `AVAudioEngine` scheduling fidelity on device;
- SwiftUI layout, colors, and animations;
- manual verification that clicks sound musically correct through device speakers.

Those areas are better covered by simulator/device smoke testing and manual audio checks.

## How To Run

Run the test target from Xcode, or from a machine with full Xcode selected:

```sh
xcodebuild test \
  -project IrregularMeasureMetronome.xcodeproj \
  -scheme IrregularMeasureMetronome \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

The Command Line Tools-only developer directory is not enough for this app's iOS test target; `xcodebuild` needs full Xcode selected with `xcode-select`.
