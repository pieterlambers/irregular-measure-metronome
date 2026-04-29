# Irregular Measure Metronome Architecture

```mermaid
flowchart TD
    A["IrregularMeasureMetronomeApp<br/>@main"] -->|"creates @StateObject"| B["MetronomeModel<br/>ObservableObject"]
    A -->|"injects via .environmentObject"| C["ContentView<br/>SwiftUI View"]

    C -->|"reads state"| B
    C -->|"user actions:<br/>play/pause, tap tempo,<br/>BPM slider, add/delete measure"| B

    B -->|"publishes UI state:<br/>bpm, isPlaying, currentBeat,<br/>currentMeasureIndex, loopCount,<br/>flashBPM, pendulumDirection,<br/>sequence, tapTempoText"| C

    B -->|"uses"| D["ClickEngine"]
    D -->|"AVAudioEngine + AVAudioPlayerNode"| E["Audio Output"]

    B -->|"stores"| F["TimeSignature[]<br/>sequence"]
    F -->|"elements are"| G["TimeSignature<br/>id, numerator, denominator, label"]

    B -->|"persists sequence"| H["UserDefaults<br/>metro.sequence.v1"]
    H -->|"load on init"| B

    B -->|"schedules beat loop with"| I["Task.sleep / async timing"]
    I -->|"advances beat + measure"| B

    C -->|"renders wrapped beat dots and sequence dots"| J["FlowLayout"]
```

## Notes

- `IrregularMeasureMetronomeApp` creates a single shared `MetronomeModel` and injects it into the SwiftUI environment.
- `ContentView` is the only UI surface in this project and drives all user interaction, including playback controls, tap tempo, measure editing, and beat visualization.
- `MetronomeModel` owns playback state, timing, tap tempo, sequence management, and persistence.
- `ClickEngine` is isolated to audio generation and playback.
- `FlowLayout` wraps the main beat dots and the compact sequence dots.
