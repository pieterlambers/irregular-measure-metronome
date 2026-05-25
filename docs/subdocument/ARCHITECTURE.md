# Irregular Measure Metronome Architecture

## Participant Links

- [MetronomeModel](./participants/metronomemodel.md)
- [ContentView](./participants/contentview.md)
- [ClickEngine](./participants/clickengine.md)
- [UserDefaults](./participants/userdefaults.md)
- [Task.sleep](./participants/tasksleep.md)
- [Audio Scheduling](./AUDIO_SCHEDULING.md)



```mermaid
flowchart TD
    A["IrregularMeasureMetronomeApp<br/>@main"] -->|"creates @StateObject"| B["MetronomeModel<br/>ObservableObject"]
    A -->|"injects via .environmentObject"| C["ContentView<br/>SwiftUI View"]

    C -->|"reads state"| B
    C -->|"user actions:<br/>song select/name/create/duplicate/delete,<br/>play/pause, count-in toggle, tap tempo,<br/>BPM slider, start measure,<br/>loop range,<br/>insert/delete measure,<br/>grouping picker"| B

    B -->|"publishes UI state:<br/>songs, currentSongID, currentSongName,<br/>bpm, isPlaying, currentBeat,<br/>currentMeasureIndex, loopCount,<br/>isCountingIn, flashBPM, pendulumDirection,<br/>sequence, startMeasureNumber,<br/>loop range, count-in setting, tapTempoText"| C

    B -->|"starts/stops buffered playback<br/>and receives beat callbacks"| D["ClickEngine"]
    D -->|"AVAudioEngine + AVAudioPlayerNode<br/>queued click + silence buffers"| E["Audio Output"]
    D -->|"scheduler queue + DispatchSourceTimer<br/>keeps audio queue filled"| K["Buffered Beat Queue"]
    D -->|"onBeat callback on main queue"| B

    B -->|"stores"| F["Song[]<br/>name, bpm, sequence,<br/>start measure, loop range,<br/>count-in setting"]
    F -->|"sequence elements are"| G["TimeSignature<br/>id, numerator, denominator,<br/>optional grouping, label"]
    B -->|"derives display numbers from"| L["startMeasureNumber + sequence index"]

    B -->|"persists song library"| H["UserDefaults<br/>metro.songLibrary.v1<br/>(migrates metro.composition.v2<br/>and metro.sequence.v1)"]
    H -->|"load on init"| B

    B -->|"uses for UI-only delays"| I["Task.sleep / async timing"]
    I -->|"clears BPM flash<br/>resets tap tempo text"| B

    C -->|"renders wrapped beat dots and sequence dots"| J["FlowLayout"]

    click B href "./participants/metronomemodel.md" "Open MetronomeModel responsibilities"
    click C href "./participants/contentview.md" "Open ContentView responsibilities"
    click D href "./participants/clickengine.md" "Open ClickEngine responsibilities"
    click H href "./participants/userdefaults.md" "Open UserDefaults responsibilities"
    click I href "./participants/tasksleep.md" "Open Task.sleep responsibilities"
    click K href "./AUDIO_SCHEDULING.md" "Open buffered audio scheduling notes"
```

## Notes

- Use the participant links above for reliable navigation. Some Markdown previews disable clickable Mermaid nodes.
- `IrregularMeasureMetronomeApp` creates a single shared `MetronomeModel` and injects it into the SwiftUI environment.
- `ContentView` is the only UI surface in this project and drives all user interaction, including song library controls, playback controls, count-in selection, tap tempo, start measure number, loop range selection, measure editing, grouping selection, and beat visualization.
- `MetronomeModel` owns published song-library state, playback state, playback lifecycle, tap tempo, sequence management, grouping validation, loop range mapping, consecutive measure numbering, persistence, and stale-callback filtering.
- `ClickEngine` owns accented, subaccented, and regular audio generation, buffered beat scheduling, silence-buffer caching, and audio-to-model beat callbacks.
- `Task.sleep` is not the beat-loop scheduler; it handles short UI delays for BPM flashing and tap-tempo reset.
- `FlowLayout` wraps the main beat dots and the compact sequence dots.
